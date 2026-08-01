import { ExecutionContext, Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { AppException } from '../exceptions/app.exception';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  handleRequest<TUser = any>(err: any, user: any, info: any, _context: ExecutionContext): TUser {
    if (err || !user) {
      throw new AppException('UNAUTHORIZED', 'Token không hợp lệ hoặc đã hết hạn');
    }
    return user as TUser;
  }
}
