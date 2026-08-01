import { IsUUID } from 'class-validator';

export class ClaimQuestDto {
  @IsUUID(undefined, { message: 'workspace_id không hợp lệ' })
  workspace_id: string;
}
