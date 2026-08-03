import { Matches } from 'class-validator';

export class SetPinDto {
  @Matches(/^\d{6}$/, { message: 'pin phải gồm đúng 6 chữ số' })
  pin: string;
}
