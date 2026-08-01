import { IsEmail, IsOptional, IsString, MinLength } from 'class-validator';

export class RegisterDto {
  @IsEmail({}, { message: 'email không hợp lệ' })
  email: string;

  @IsString()
  @MinLength(8, { message: 'password phải có ít nhất 8 ký tự' })
  password: string;

  @IsString()
  @MinLength(1, { message: 'full_name là bắt buộc' })
  full_name: string;

  @IsOptional()
  @IsString()
  phone?: string;
}
