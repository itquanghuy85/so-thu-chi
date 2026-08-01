import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ReportsService } from './reports.service';
import { CashflowReportQueryDto } from './dto/cashflow-report.query.dto';
import { DailySummaryQueryDto } from './dto/daily-summary.query.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { WorkspaceMemberGuard } from '../../common/guards/workspace-member.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { JwtUserPayload } from '../../common/decorators/current-user.decorator';

@UseGuards(JwtAuthGuard, WorkspaceMemberGuard)
@Controller('reports')
export class ReportsController {
  constructor(private readonly reportsService: ReportsService) {}

  @Get('cashflow')
  cashflow(@CurrentUser() user: JwtUserPayload, @Query() query: CashflowReportQueryDto) {
    return this.reportsService.cashflow(user.id, query);
  }

  @Get('daily-summary')
  dailySummary(@CurrentUser() user: JwtUserPayload, @Query() query: DailySummaryQueryDto) {
    return this.reportsService.dailySummary(user.id, query);
  }
}
