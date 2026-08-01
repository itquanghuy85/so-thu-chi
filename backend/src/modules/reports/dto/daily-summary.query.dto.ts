import { IsDateString, IsUUID } from 'class-validator';

export class DailySummaryQueryDto {
  @IsUUID(undefined, { message: 'workspace_id không hợp lệ' })
  workspace_id: string;

  @IsDateString(undefined, { message: 'from_date phải là ngày hợp lệ (YYYY-MM-DD)' })
  from_date: string;

  @IsDateString(undefined, { message: 'to_date phải là ngày hợp lệ (YYYY-MM-DD)' })
  to_date: string;
}
