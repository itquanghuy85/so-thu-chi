import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import type { JwtSignOptions } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { AppException } from '../../common/exceptions/app.exception';
import { FirebaseAdminService } from '../../common/firebase/firebase-admin.service';
import { UsersService } from '../users/users.service';
import { User } from '../users/entities/user.entity';
import { Workspace } from '../workspaces/entities/workspace.entity';
import { WorkspaceMember } from '../workspaces/entities/workspace-member.entity';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { SocialLoginDto } from './dto/social-login.dto';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { ChangePasswordDto } from './dto/change-password.dto';

export interface TokenPair {
  access_token: string;
  refresh_token: string;
}

const SALT_ROUNDS = 10;

@Injectable()
export class AuthService {
  constructor(
    private readonly usersService: UsersService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly firebaseAdminService: FirebaseAdminService,
    @InjectRepository(Workspace) private readonly workspacesRepository: Repository<Workspace>,
    @InjectRepository(WorkspaceMember) private readonly membersRepository: Repository<WorkspaceMember>,
  ) {}

  async register(dto: RegisterDto): Promise<{ user: User } & TokenPair> {
    const existing = await this.usersService.findByEmail(dto.email);
    if (existing) {
      throw new AppException('CONFLICT', 'Email đã được đăng ký');
    }
    const passwordHash = await bcrypt.hash(dto.password, SALT_ROUNDS);
    const user = await this.usersService.create({
      email: dto.email,
      passwordHash,
      fullName: dto.full_name,
      phone: dto.phone ?? null,
    });
    return { user, ...this.issueTokens(user) };
  }

  async login(dto: LoginDto): Promise<{ user: User } & TokenPair> {
    const user = await this.usersService.findByEmail(dto.email);
    if (!user || !user.passwordHash) {
      // No account, or the account was created via Google/Apple and never set a password.
      throw new AppException('INVALID_CREDENTIALS', 'Email hoặc mật khẩu không đúng');
    }
    const matches = await bcrypt.compare(dto.password, user.passwordHash);
    if (!matches) {
      throw new AppException('INVALID_CREDENTIALS', 'Email hoặc mật khẩu không đúng');
    }
    return { user, ...this.issueTokens(user) };
  }

  /// Google/Apple sign-in: client already authenticated with Firebase and
  /// hands us the resulting Firebase ID token. We verify it, then
  /// find-or-create the local user by email — same shape response as
  /// register/login so the app doesn't need to special-case this.
  async socialLogin(dto: SocialLoginDto): Promise<{ user: User } & TokenPair> {
    const verified = await this.firebaseAdminService.verifyIdToken(dto.id_token);
    if (!verified.email) {
      throw new AppException('VALIDATION_ERROR', 'Không lấy được email từ tài khoản đăng nhập');
    }

    let user = await this.usersService.findByEmail(verified.email);
    if (!user) {
      user = await this.usersService.create({
        email: verified.email,
        passwordHash: null,
        fullName: verified.fullName ?? verified.email.split('@')[0],
        phone: null,
      });
    }
    return { user, ...this.issueTokens(user) };
  }

  async refresh(refreshToken: string): Promise<TokenPair> {
    let payload: { sub: string; email: string };
    try {
      payload = await this.jwtService.verifyAsync(refreshToken, {
        secret: this.configService.get<string>('JWT_REFRESH_SECRET'),
      });
    } catch {
      throw new AppException('UNAUTHORIZED', 'Refresh token không hợp lệ hoặc đã hết hạn');
    }
    const user = await this.usersService.findById(payload.sub);
    if (!user) {
      throw new AppException('UNAUTHORIZED', 'Refresh token không hợp lệ');
    }
    return this.issueTokens(user);
  }

  /// "Xóa tài khoản" (Cài đặt → Bảo mật): irreversible. Blocked if the user
  /// is the sole owner of a workspace that has other members — deleting the
  /// user would cascade-delete that workspace (see `Workspace.owner`'s
  /// `onDelete: 'CASCADE'`), wiping data those other members contributed
  /// too, not just the requester's own. Solo workspaces (no other members)
  /// cascade-delete along with the account, which is the expected behavior.
  /// Transactions the user created in workspaces they don't own are kept
  /// (`Transaction.createdByUser` is `SET NULL`), preserving the ledger.
  async deleteAccount(userId: string): Promise<void> {
    const ownedWorkspaces = await this.workspacesRepository.find({ where: { ownerId: userId } });
    const blocking: string[] = [];
    for (const workspace of ownedWorkspaces) {
      const memberCount = await this.membersRepository.count({ where: { workspaceId: workspace.id } });
      if (memberCount > 1) {
        blocking.push(workspace.name);
      }
    }
    if (blocking.length > 0) {
      throw new AppException(
        'CONFLICT',
        `Bạn đang là chủ sở hữu của không gian làm việc có thành viên khác (${blocking.join(', ')}). Vui lòng xoá hết thành viên hoặc chuyển quyền sở hữu trước khi xoá tài khoản.`,
      );
    }
    await this.usersService.delete(userId);
  }

  /// "Trang cá nhân": name/phone only — email and password have their own
  /// dedicated flows (email is the login identity, never editable here;
  /// password goes through `changePassword` since it needs the current
  /// password re-checked).
  async updateProfile(userId: string, dto: UpdateProfileDto): Promise<User> {
    return this.usersService.updateProfile(userId, {
      fullName: dto.full_name,
      phone: dto.phone,
    });
  }

  async changePassword(userId: string, dto: ChangePasswordDto): Promise<void> {
    const user = await this.usersService.findById(userId);
    if (!user) {
      throw new AppException('NOT_FOUND', 'Không tìm thấy người dùng');
    }
    if (!user.passwordHash) {
      // Google/Apple-only account — there's no existing password to
      // "change" against; setting one from scratch is a different, not-yet-
      // built flow (would need re-verifying the social identity, not a
      // current-password check).
      throw new AppException(
        'VALIDATION_ERROR',
        'Tài khoản này đăng nhập bằng Google/Apple, chưa có mật khẩu để đổi',
      );
    }
    const matches = await bcrypt.compare(dto.current_password, user.passwordHash);
    if (!matches) {
      throw new AppException('INVALID_CREDENTIALS', 'Mật khẩu hiện tại không đúng');
    }
    const newHash = await bcrypt.hash(dto.new_password, SALT_ROUNDS);
    await this.usersService.updatePasswordHash(userId, newHash);
  }

  /// "Ảnh đại diện": returns the new user record (with `avatarUrl` set) so
  /// the caller doesn't need a second round-trip to refresh the profile.
  async updateAvatar(userId: string, buffer: Buffer, contentType: string): Promise<User> {
    const url = await this.firebaseAdminService.uploadAvatar(userId, buffer, contentType);
    await this.usersService.updateAvatarUrl(userId, url);
    return (await this.usersService.findById(userId))!;
  }

  private issueTokens(user: User): TokenPair {
    const claims = { sub: user.id, email: user.email };
    const access_token = this.jwtService.sign(claims, {
      secret: this.configService.get<string>('JWT_ACCESS_SECRET'),
      expiresIn: this.configService.get<string>('JWT_ACCESS_EXPIRES') || '15m',
    } as JwtSignOptions);
    const refresh_token = this.jwtService.sign(claims, {
      secret: this.configService.get<string>('JWT_REFRESH_SECRET'),
      expiresIn: this.configService.get<string>('JWT_REFRESH_EXPIRES') || '30d',
    } as JwtSignOptions);
    return { access_token, refresh_token };
  }
}
