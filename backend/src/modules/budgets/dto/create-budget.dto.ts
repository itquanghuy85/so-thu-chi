import { IsInt, IsOptional, IsUUID, Min } from 'class-validator';

export class CreateBudgetDto {
  @IsOptional()
  @IsUUID(undefined, { message: 'category_id không hợp lệ' })
  category_id?: string;

  @IsInt({ message: 'limit_amount phải là số nguyên' })
  @Min(1, { message: 'limit_amount phải lớn hơn 0' })
  limit_amount: number;
}
