import { IsString, MinLength } from 'class-validator';

export class ChangePasswordDto {
  @IsString()
  current_password: string;

  @IsString()
  @MinLength(8, { message: 'new_password phải có ít nhất 8 ký tự' })
  new_password: string;
}
