import { IsEnum, IsString, MinLength } from 'class-validator';

export class CreateWorkspaceDto {
  @IsString()
  @MinLength(1, { message: 'name là bắt buộc' })
  name: string;

  @IsEnum(['shop', 'family'], { message: 'type phải là shop hoặc family' })
  type: 'shop' | 'family';
}
