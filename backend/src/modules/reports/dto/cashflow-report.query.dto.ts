import { IsEnum, IsUUID } from 'class-validator';

export type ReportPeriod = 'this_week' | 'this_month' | 'this_year';

export class CashflowReportQueryDto {
  @IsUUID(undefined, { message: 'workspace_id không hợp lệ' })
  workspace_id: string;

  @IsEnum(['this_week', 'this_month', 'this_year'], {
    message: 'period phải là this_week, this_month hoặc this_year',
  })
  period: ReportPeriod;
}
