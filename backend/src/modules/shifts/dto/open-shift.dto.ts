import { IsOptional, IsString } from 'class-validator';

export class OpenShiftDto {
  @IsOptional()
  @IsString()
  note?: string;
}
