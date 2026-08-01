import { IsOptional, IsString } from 'class-validator';

export class CloseShiftDto {
  @IsOptional()
  @IsString()
  note?: string;
}
