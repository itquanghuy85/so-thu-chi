import { IsUUID } from 'class-validator';

export class GamificationProfileQueryDto {
  @IsUUID(undefined, { message: 'workspace_id không hợp lệ' })
  workspace_id: string;
}
