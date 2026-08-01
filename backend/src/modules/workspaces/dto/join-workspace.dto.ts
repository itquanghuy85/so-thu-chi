import { IsString, MinLength } from 'class-validator';

export class JoinWorkspaceDto {
  @IsString()
  @MinLength(1, { message: 'invite_code là bắt buộc' })
  invite_code: string;
}
