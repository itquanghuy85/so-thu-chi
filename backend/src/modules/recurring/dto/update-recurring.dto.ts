import { IsBoolean, IsOptional } from 'class-validator';

export class UpdateRecurringDto {
  @IsOptional()
  @IsBoolean()
  active?: boolean;
}
