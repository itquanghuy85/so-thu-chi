import { Body, Controller, Get, HttpCode, Post, UseGuards } from '@nestjs/common';
import { AuthService } from './auth.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { SocialLoginDto } from './dto/social-login.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { JwtUserPayload } from '../../common/decorators/current-user.decorator';
import { UsersService } from '../users/users.service';
import { AppException } from '../../common/exceptions/app.exception';
import { User } from '../users/entities/user.entity';

function toPublicUser(user: User) {
  return { id: user.id, email: user.email, full_name: user.fullName };
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
    return { id: user.id, email: user.email, full_name: user.fullName, phone: user.phone, locale: user.locale };
  }
}
