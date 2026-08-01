import { Type } from 'class-transformer';
import { IsDateString, IsEnum, IsInt, IsOptional, IsUUID, Min } from 'class-validator';

export class ListTransactionsQueryDto {
  @IsUUID(undefined, { message: 'workspace_id không hợp lệ' })
  workspace_id: string;

  @IsOptional()
  @IsEnum(['income', 'expense', 'transfer', 'debt_increase', 'debt_decrease'], { message: 'type không hợp lệ' })
  type?: 'income' | 'expense' | 'transfer' | 'debt_increase' | 'debt_decrease';

  @IsOptional()
  @IsUUID(undefined, { message: 'vault_id không hợp lệ' })
  vault_id?: string;

  // Inclusive ISO date/datetime bounds on `created_at`, used by the Reports
  // screens to fetch just the transactions in a given period instead of
  // over-fetching. Both optional/independent.
  @IsOptional()
  @IsDateString(undefined, { message: 'from_date không hợp lệ' })
  from_date?: string;

  @IsOptional()
  @IsDateString(undefined, { message: 'to_date không hợp lệ' })
  to_date?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number = 1;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  limit?: number = 20;
}
