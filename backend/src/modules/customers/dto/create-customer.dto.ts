import { IsOptional, IsString, MinLength } from 'class-validator';

export class CreateCustomerDto {
  @IsString()
  @MinLength(1, { message: 'name là bắt buộc' })
  name: string;

  @IsOptional()
  @IsString()
  phone?: string;
}
