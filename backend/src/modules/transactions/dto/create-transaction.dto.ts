import { IsEnum, IsIn, IsInt, IsOptional, IsString, IsUUID, Min, ValidateIf } from 'class-validator';

export type TransactionTypeDto = 'income' | 'expense' | 'transfer' | 'debt_increase' | 'debt_decrease';

export class CreateTransactionDto {
  @IsUUID(undefined, { message: 'workspace_id không hợp lệ' })
  workspace_id: string;

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

  // Optional giá vốn (Mục — "tính lợi nhuận theo vốn"), meaningful on
  // `income` transactions only — see Transaction.costAmount doc comment.
  // Accepted (and ignored by the profit formula) on other types too rather
  // than rejected, so the mobile form doesn't need type-conditional
  // validation just to submit it.
  @IsOptional()
  @IsInt({ message: 'cost_amount phải là số nguyên' })
  @Min(0, { message: 'cost_amount không được âm' })
  cost_amount?: number;

  // Required for: expense, transfer
  @ValidateIf((o: CreateTransactionDto) => o.type === 'expense' || o.type === 'transfer')
  @IsUUID(undefined, { message: 'from_vault_id là bắt buộc cho giao dịch này' })
  from_vault_id?: string;

  // Required for: income, transfer, debt_decrease
  @ValidateIf((o: CreateTransactionDto) => o.type === 'income' || o.type === 'transfer' || o.type === 'debt_decrease')
  @IsUUID(undefined, { message: 'to_vault_id là bắt buộc cho giao dịch này' })
  to_vault_id?: string;

  // Required for: debt_increase, debt_decrease
  @ValidateIf((o: CreateTransactionDto) => o.type === 'debt_increase' || o.type === 'debt_decrease')
  @IsUUID(undefined, { message: 'customer_id là bắt buộc cho giao dịch này' })
  customer_id?: string;

  // Optional, defaults to 'manual'. 'voice' grants an extra XP award
  // (Mục 9 "Sử dụng voice: +5 XP") — set by the mobile app's voice-input
  // confirmation form (Mục 10), never inferred server-side. 'recurring' is
  // set by RecurringService when materializing a due recurring transaction.
  @IsOptional()
  @IsIn(['manual', 'voice', 'recurring'], { message: 'source không hợp lệ' })
  source?: 'manual' | 'voice' | 'recurring';
}
