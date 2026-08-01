import { ArrayMinSize, IsArray, IsInt, IsOptional, IsString, IsUUID, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';

export class DailyClosingEntryDto {
  @IsUUID(undefined, { message: 'vault_id không hợp lệ' })
  vault_id: string;

  @IsInt({ message: 'actual_balance phải là số nguyên' })
  actual_balance: number;
}

export class CreateDailyClosingDto {
  @IsArray()
  @ArrayMinSize(1, { message: 'Cần ít nhất một quỹ để chốt sổ' })
  @ValidateNested({ each: true })
  @Type(() => DailyClosingEntryDto)
  entries: DailyClosingEntryDto[];

  @IsOptional()
  @IsString()
  note?: string;
}
