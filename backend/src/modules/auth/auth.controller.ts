import { Body, Controller, Delete, Get, HttpCode, Patch, Post, UploadedFile, UseGuards, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import type { Express } from 'express';
import { AuthService } from './auth.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { SocialLoginDto } from './dto/social-login.dto';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { ChangePasswordDto } from './dto/change-password.dto';
import { SetPinDto } from './dto/set-pin.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { JwtUserPayload } from '../../common/decorators/current-user.decorator';
import { UsersService } from '../users/users.service';
import { AppException } from '../../common/exceptions/app.exception';
import { User } from '../users/entities/user.entity';

function toPublicUser(user: User) {
  return { id: user.id, email: user.email, full_name: user.fullName, avatar_url: user.avatarUrl };
}

@Controller('auth')
export class AuthController {
  constructor(
    private readonly authService: AuthService,
    private readonly usersService: UsersService,
  ) {}

  @Post('register')
  async register(@Body() dto: RegisterDto) {
    const { user, access_token, refresh_token } = await this.authService.register(dto);
    return { user: toPublicUser(user), access_token, refresh_token };
  }

  @Post('login')
  @HttpCode(200)
  async login(@Body() dto: LoginDto) {
    const { user, access_token, refresh_token } = await this.authService.login(dto);
    return { user: toPublicUser(user), access_token, refresh_token };
  }

  @Post('social-login')
  @HttpCode(200)
  async socialLogin(@Body() dto: SocialLoginDto) {
    const { user, access_token, refresh_token } = await this.authService.socialLogin(dto);
    return { user: toPublicUser(user), access_token, refresh_token };
  }

  @Post('refresh')
  @HttpCode(200)
  refresh(@Body() dto: RefreshTokenDto) {
    return this.authService.refresh(dto.refresh_token);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me')
  async me(@CurrentUser() currentUser: JwtUserPayload) {
    const user = await this.usersService.findById(currentUser.id);
    if (!user) {
      throw new AppException('NOT_FOUND', 'Không tìm thấy người dùng');
    }
    return {
      id: user.id,
      email: user.email,
      full_name: user.fullName,
      phone: user.phone,
      avatar_url: user.avatarUrl,
      locale: user.locale,
    };
  }

  /// "Trang cá nhân": edits name/phone. Email is the login identity (never
  /// editable here); password has its own endpoint below since it needs
  /// the current password re-checked, not a plain field update.
  @UseGuards(JwtAuthGuard)
  @Patch('me')
  async updateProfile(@CurrentUser() currentUser: JwtUserPayload, @Body() dto: UpdateProfileDto) {
    const user = await this.authService.updateProfile(currentUser.id, dto);
    return toPublicUser(user);
  }

  @UseGuards(JwtAuthGuard)
  @Patch('change-password')
  @HttpCode(200)
  async changePassword(@CurrentUser() currentUser: JwtUserPayload, @Body() dto: ChangePasswordDto) {
    await this.authService.changePassword(currentUser.id, dto);
    return { message: 'Mật khẩu đã được cập nhật' };
  }

  /// "Ảnh đại diện": multipart upload, field name `file`. 5MB cap and an
  /// image-only mimetype check are enforced here rather than relying on
  /// Firebase Storage to reject anything — a clear 4xx beats a vague
  /// upload failure for something this user-facing.
  @UseGuards(JwtAuthGuard)
  @Post('avatar')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 5 * 1024 * 1024 } }))
  async uploadAvatar(@CurrentUser() currentUser: JwtUserPayload, @UploadedFile() file?: Express.Multer.File) {
    if (!file) {
      throw new AppException('VALIDATION_ERROR', 'Vui lòng chọn một ảnh');
    }
    if (!file.mimetype.startsWith('image/')) {
      throw new AppException('VALIDATION_ERROR', 'File phải là ảnh (jpg, png...)');
    }
    const user = await this.authService.updateAvatar(currentUser.id, file.buffer, file.mimetype);
    return toPublicUser(user);
  }

  /// "Cài PIN / Vân tay": account-wide, not per-device — see
  /// `User.pinHash`'s doc comment for why and how offline verification
  /// still works on a device that hasn't set this PIN itself yet.
  @UseGuards(JwtAuthGuard)
  @Get('pin')
  getPinStatus(@CurrentUser() currentUser: JwtUserPayload) {
    return this.authService.getPinStatus(currentUser.id);
  }

  @UseGuards(JwtAuthGuard)
  @Patch('pin')
  @HttpCode(200)
  async setPin(@CurrentUser() currentUser: JwtUserPayload, @Body() dto: SetPinDto) {
    await this.authService.setPin(currentUser.id, dto);
    return { message: 'Đã đặt mã PIN' };
  }

  @UseGuards(JwtAuthGuard)
  @Delete('pin')
  @HttpCode(200)
  async clearPin(@CurrentUser() currentUser: JwtUserPayload) {
    await this.authService.clearPin(currentUser.id);
    return { message: 'Đã tắt khoá bằng mã PIN' };
  }

  @UseGuards(JwtAuthGuard)
  @Delete('account')
  @HttpCode(200)
  async deleteAccount(@CurrentUser() currentUser: JwtUserPayload) {
    await this.authService.deleteAccount(currentUser.id);
    return { message: 'Tài khoản đã được xoá' };
  }
}
