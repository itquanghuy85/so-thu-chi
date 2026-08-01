import { IsInt, IsOptional, IsString } from 'class-validator';

export class ReconcileVaultDto {
  @IsInt({ message: 'actual_balance phải là số nguyên' })
  actual_balance: number;

  @IsOptional()
  @IsString()
  reason?: string;
}
