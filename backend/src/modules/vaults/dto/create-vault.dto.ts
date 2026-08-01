import { IsEnum, IsInt, IsOptional, IsString, Min, MinLength } from 'class-validator';

export class CreateVaultDto {
  @IsString()
  @MinLength(1, { message: 'name là bắt buộc' })
  name: string;

  @IsEnum(['cash', 'bank', 'ewallet'], { message: 'type phải là cash, bank hoặc ewallet' })
  type: 'cash' | 'bank' | 'ewallet';

  @IsOptional()
  @IsInt({ message: 'initial_balance phải là số nguyên' })
  @Min(0, { message: 'initial_balance phải >= 0' })
  initial_balance?: number;
}
