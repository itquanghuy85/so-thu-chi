import { IsEnum, IsOptional } from 'class-validator';

export class ListCategoriesQueryDto {
  @IsOptional()
  @IsEnum(['income', 'expense'], { message: 'group phải là income hoặc expense' })
  group?: 'income' | 'expense';
}
