import { IsEmail, IsString, MinLength } from 'class-validator';

export class LoginDto {
  @IsEmail({}, { message: 'email không hợp lệ' })
  email: string;

  @IsString()
  @MinLength(1, { message: 'password là bắt buộc' })
  password: string;
}
