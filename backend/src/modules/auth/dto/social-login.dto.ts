import { IsIn, IsString, MinLength } from 'class-validator';

export class SocialLoginDto {
  @IsString()
  @MinLength(1, { message: 'id_token là bắt buộc' })
  id_token: string;

  @IsIn(['google', 'apple'], { message: 'provider phải là "google" hoặc "apple"' })
  provider: 'google' | 'apple';
}
