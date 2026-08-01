import { IsEnum, IsOptional, IsString, MinLength } from 'class-validator';

export class CreateCategoryDto {
  @IsString()
  @MinLength(1, { message: 'name là bắt buộc' })
  name: string;

  @IsEnum(['income', 'expense'], { message: 'group_name phải là income hoặc expense' })
  group_name: 'income' | 'expense';

  @IsOptional()
  @IsString()
  icon?: string;
}
