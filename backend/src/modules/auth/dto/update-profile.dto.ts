import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class UpdateProfileDto {
  @IsOptional()
  @IsString()
  @MinLength(1, { message: 'full_name không được để trống' })
  @MaxLength(100, { message: 'full_name tối đa 100 ký tự' })
  full_name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(20, { message: 'phone tối đa 20 ký tự' })
  phone?: string;
}
