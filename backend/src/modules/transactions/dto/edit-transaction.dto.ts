import { IsEnum, IsInt, IsOptional, IsString, IsUUID, Min, ValidateIf } from 'class-validator';
import type { TransactionTypeDto } from './create-transaction.dto';

/// Body for `PATCH /transactions/:id` (Mục — "sửa giao dịch"). Deliberately
/// the same field shape as `CreateTransactionDto` minus `workspace_id`
/// (derived server-side from the transaction being edited, so a client
/// can't move a transaction to a different workspace by editing it) and
/// `source` (an edit is never voice/recurring-originated). See
/// `TransactionsService.edit` — this never mutates the original row, it
/// voids it and creates a fresh one with these values.
export class EditTransactionDto {
  @IsEnum(['income', 'expense', 'transfer', 'debt_increase', 'debt_decrease'], {
    message: 'type không hợp lệ',
  })
  type: TransactionTypeDto;

  @IsInt({ message: 'amount phải là số nguyên' })
  @Min(1, { message: 'amount phải lớn hơn 0' })
  amount: number;

  @IsOptional()
  @IsUUID(undefined, { message: 'category_id không hợp lệ' })
  category_id?: string;

  @IsOptional()
  @IsString()
  note?: string;

  @IsOptional()
  @IsInt({ message: 'cost_amount phải là số nguyên' })
  @Min(0, { message: 'cost_amount không được âm' })
  cost_amount?: number;

  @ValidateIf((o: EditTransactionDto) => o.type === 'expense' || o.type === 'transfer')
  @IsUUID(undefined, { message: 'from_vault_id là bắt buộc cho giao dịch này' })
  from_vault_id?: string;

  @ValidateIf((o: EditTransactionDto) => o.type === 'income' || o.type === 'transfer' || o.type === 'debt_decrease')
  @IsUUID(undefined, { message: 'to_vault_id là bắt buộc cho giao dịch này' })
  to_vault_id?: string;

  @ValidateIf((o: EditTransactionDto) => o.type === 'debt_increase' || o.type === 'debt_decrease')
  @IsUUID(undefined, { message: 'customer_id là bắt buộc cho giao dịch này' })
  customer_id?: string;

  // Optional human-readable reason, stored on the audit log entry only —
  // not on the transaction itself.
  @IsOptional()
  @IsString()
  reason?: string;
}
