import { IsOptional, IsString } from 'class-validator';

export class VoidTransactionDto {
  @IsOptional()
  @IsString()
  reason?: string;
}
