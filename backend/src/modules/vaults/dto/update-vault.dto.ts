import { IsEnum, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

/// Partial update for a vault (rename and/or change type). Amounts are
/// deliberately not mutable here — reconciling is the only path that adjusts
/// `current_balance`, so the ledger can't be distorted by a stray update.
export class UpdateVaultDto {
  @IsOptional()
  @IsString()
  @MinLength(1, { message: 'name không được rỗng' })
  @MaxLength(100, { message: 'name tối đa 100 ký tự' })
  name?: string;

  @IsOptional()
  @IsEnum(['cash', 'bank', 'ewallet'], { message: 'type phải là cash, bank hoặc ewallet' })
  type?: 'cash' | 'bank' | 'ewallet';
}