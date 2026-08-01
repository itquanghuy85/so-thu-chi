import { IsDateString, IsEnum, IsIn, IsInt, IsOptional, IsString, IsUUID, Min, ValidateIf } from 'class-validator';
import type { TransactionTypeDto } from '../../transactions/dto/create-transaction.dto';

export class CreateRecurringDto {
  @IsEnum(['income', 'expense', 'transfer', 'debt_increase', 'debt_decrease'], { message: 'type không hợp lệ' })
  type: TransactionTypeDto;

  @IsInt({ message: 'amount phải là số nguyên' })
  @Min(1, { message: 'amount phải lớn hơn 0' })
  amount: number;

  @IsOptional()
  @IsUUID(undefined, { message: 'category_id không hợp lệ' })
  category_id?: string;

  @ValidateIf((o: CreateRecurringDto) => o.type === 'expense' || o.type === 'transfer')
  @IsUUID(undefined, { message: 'from_vault_id là bắt buộc cho giao dịch này' })
  from_vault_id?: string;

  @ValidateIf((o: CreateRecurringDto) => o.type === 'income' || o.type === 'transfer' || o.type === 'debt_decrease')
  @IsUUID(undefined, { message: 'to_vault_id là bắt buộc cho giao dịch này' })
  to_vault_id?: string;

  @ValidateIf((o: CreateRecurringDto) => o.type === 'debt_increase' || o.type === 'debt_decrease')
  @IsUUID(undefined, { message: 'customer_id là bắt buộc cho giao dịch này' })
  customer_id?: string;

  @IsOptional()
  @IsString()
  note?: string;

  @IsIn(['daily', 'weekly', 'monthly'], { message: 'frequency không hợp lệ' })
  frequency: 'daily' | 'weekly' | 'monthly';

  @IsDateString(undefined, { message: 'start_date không hợp lệ' })
  start_date: string;
}
