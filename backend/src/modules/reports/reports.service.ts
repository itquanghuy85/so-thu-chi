import { Injectable } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { Transaction } from '../transactions/entities/transaction.entity';
import { CashflowReportQueryDto, ReportPeriod } from './dto/cashflow-report.query.dto';
import { assertWorkspaceMember } from '../../common/utils/workspace-access.util';

@Injectable()
export class ReportsService {
  constructor(@InjectDataSource() private readonly dataSource: DataSource) {}

  async cashflow(userId: string, query: CashflowReportQueryDto) {
    await assertWorkspaceMember(this.dataSource, query.workspace_id, userId);

    const { from, to } = this.resolvePeriodRange(query.period);

    const rows = await this.dataSource
      .getRepository(Transaction)
      .createQueryBuilder('t')
      .select('t.type', 'type')
      .addSelect('COALESCE(SUM(t.amount), 0)', 'total')
      .where('t.workspaceId = :workspaceId', { workspaceId: query.workspace_id })
      .andWhere('t.status = :status', { status: 'completed' })
      .andWhere('t.type IN (:...types)', { types: ['income', 'expense'] })
      .andWhere('t.createdAt >= :from', { from })
      .andWhere('t.createdAt < :to', { to })
      .groupBy('t.type')
      .getRawMany<{ type: 'income' | 'expense'; total: string }>();

    const totals: Record<'income' | 'expense', number> = { income: 0, expense: 0 };
    for (const row of rows) {
      totals[row.type] = parseInt(row.total, 10) || 0;
    }

    return {
      period: query.period,
      total_income: totals.income,
      total_expense: totals.expense,
      net_cashflow: totals.income - totals.expense,
    };
  }

  private resolvePeriodRange(period: ReportPeriod): { from: Date; to: Date } {
    const now = new Date();
    const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    switch (period) {
      case 'this_week': {
        // Monday-start week.
        const day = startOfDay.getDay();
        const diffToMonday = day === 0 ? 6 : day - 1;
        const from = new Date(startOfDay);
        from.setDate(from.getDate() - diffToMonday);
        const to = new Date(from);
        to.setDate(to.getDate() + 7);
        return { from, to };
      }
      case 'this_month': {
        const from = new Date(now.getFullYear(), now.getMonth(), 1);
        const to = new Date(now.getFullYear(), now.getMonth() + 1, 1);
        return { from, to };
      }
      case 'this_year': {
        const from = new Date(now.getFullYear(), 0, 1);
        const to = new Date(now.getFullYear() + 1, 0, 1);
        return { from, to };
      }
    }
  }
}
