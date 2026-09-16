import { IsBoolean, IsDateString, IsEnum, IsIn, IsInt, IsOptional, IsString, IsUUID, Min, ValidateIf } from 'class-validator';
import type { TransactionTypeDto } from '../../transactions/dto/create-transaction.dto';

/// Partial update for a recurring entry — every one of the template's fields
/// (plus the `active` toggle the list screen uses) can be edited individually.
/// As with CreateRecurringDto, vault/customer requirements follow `type`, so
/// editing `type` together with the right vault keys in one PATCH is fine.
export class UpdateRecurringDto {
  @IsOptional()
  @IsBoolean()
  active?: boolean;

  @IsOptional()
  @IsEnum(['income', 'expense', 'transfer', 'debt_increase', 'debt_decrease'], { message: 'type không hợp lệ' })
  type?: TransactionTypeDto;

  @IsOptional()
  @IsInt({ message: 'amount phải là số nguyên' })
  @Min(1, { message: 'amount phải lớn hơn 0' })
  amount?: number;

  @IsOptional()
  @IsUUID(undefined, { message: 'category_id không hợp lệ' })
  category_id?: string;

  @ValidateIf((o: UpdateRecurringDto) => o.type === 'expense' || o.type === 'transfer')
  @IsUUID(undefined, { message: 'from_vault_id là bắt buộc cho giao dịch này' })
  from_vault_id?: string;

  @ValidateIf((o: UpdateRecurringDto) => o.type === 'income' || o.type === 'transfer' || o.type === 'debt_decrease')
  @IsUUID(undefined, { message: 'to_vault_id là bắt buộc cho giao dịch này' })
  to_vault_id?: string;

  @ValidateIf((o: UpdateRecurringDto) => o.type === 'debt_increase' || o.type === 'debt_decrease')
  @IsUUID(undefined, { message: 'customer_id là bắt buộc cho giao dịch này' })
  customer_id?: string;

  @IsOptional()
  @IsString()
  note?: string;

  @IsOptional()
  @IsIn(['daily', 'weekly', 'monthly'], { message: 'frequency không hợp lệ' })
  frequency?: 'daily' | 'weekly' | 'monthly';

  @IsOptional()
  @IsDateString(undefined, { message: 'start_date không hợp lệ' })
  start_date?: string;
}