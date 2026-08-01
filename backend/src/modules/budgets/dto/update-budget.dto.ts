import { IsInt, Min } from 'class-validator';

export class UpdateBudgetDto {
  @IsInt({ message: 'limit_amount phải là số nguyên' })
  @Min(1, { message: 'limit_amount phải lớn hơn 0' })
  limit_amount: number;
}
