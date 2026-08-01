import { IsString, MinLength } from 'class-validator';

export class RefreshTokenDto {
  @IsString()
  @MinLength(1, { message: 'refresh_token là bắt buộc' })
  refresh_token: string;
}
