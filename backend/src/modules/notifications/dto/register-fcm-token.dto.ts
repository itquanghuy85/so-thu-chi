import { IsString, MinLength } from 'class-validator';

export class RegisterFcmTokenDto {
  @IsString()
  @MinLength(10, { message: 'token không hợp lệ' })
  token: string;
}
