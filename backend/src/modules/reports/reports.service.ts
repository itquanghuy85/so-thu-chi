import { Injectable } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { Transaction } from '../transactions/entities/transaction.entity';
import { CashflowReportQueryDto, ReportPeriod } from './dto/cashflow-report.query.dto';
import { DailySummaryQueryDto } from './dto/daily-summary.query.dto';
import { AppException } from '../../common/exceptions/app.exception';
import { assertWorkspaceMember } from '../../common/utils/workspace-access.util';

const MAX_DAILY_SUMMARY_RANGE_DAYS = 400;

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
      .addSelect('COALESCE(SUM(t.costAmount), 0)', 'cost')
      .where('t.workspaceId = :workspaceId', { workspaceId: query.workspace_id })
      .andWhere('t.status = :status', { status: 'completed' })
      .andWhere('t.type IN (:...types)', { types: ['income', 'expense'] })
      .andWhere('t.createdAt >= :from', { from })
      .andWhere('t.createdAt < :to', { to })
      .groupBy('t.type')
      .getRawMany<{ type: 'income' | 'expense'; total: string; cost: string }>();

    const totals: Record<'income' | 'expense', number> = { income: 0, expense: 0 };
    let totalCost = 0;
    for (const row of rows) {
      totals[row.type] = parseInt(row.total, 10) || 0;
      if (row.type === 'income') totalCost = parseInt(row.cost, 10) || 0;
    }

    return {
      period: query.period,
      total_income: totals.income,
      total_expense: totals.expense,
      // Pure cash movement — unaffected by giá vốn, which isn't a cash
      // event. Kept distinct from `gross_profit` below on purpose.
      net_cashflow: totals.income - totals.expense,
      total_cost: totalCost,
      // Lợi nhuận gộp (Mục — "tính lợi nhuận theo vốn"): revenue minus the
      // cost recorded against it, minus operating expense. Falls back to
      // exactly `net_cashflow` when no transaction in the period has a
      // recorded cost (totalCost === 0), so this is a pure superset of the
      // pre-existing behavior, not a breaking change.
      gross_profit: totals.income - totalCost - totals.expense,
    };
  }

  /// Per-day revenue/expense/profit rollup (Mục — "tính lãi/lỗ hàng
  /// ngày"). Deliberately computed on demand from the ledger via a single
  /// GROUP BY rather than a scheduled job writing a snapshot table: the
  /// ledger already *is* the history, so there's nothing to keep in sync
  /// and no cron/scheduler infrastructure needed (same reasoning as
  /// recurring transactions and the gamification weekly quest elsewhere in
  /// this codebase). Missing days in the range simply have no row — the
  /// caller (mobile) fills gaps with zero when rendering a chart/table.
  async dailySummary(userId: string, query: DailySummaryQueryDto) {
    await assertWorkspaceMember(this.dataSource, query.workspace_id, userId);

    const from = new Date(query.from_date);
    const to = new Date(query.to_date);
    to.setDate(to.getDate() + 1); // to_date is inclusive on the client side

    const rangeDays = (to.getTime() - from.getTime()) / (24 * 60 * 60 * 1000);
    if (rangeDays <= 0 || rangeDays > MAX_DAILY_SUMMARY_RANGE_DAYS) {
      throw new AppException('VALIDATION_ERROR', `Khoảng thời gian phải từ 1 đến ${MAX_DAILY_SUMMARY_RANGE_DAYS} ngày`);
    }

    const rows = await this.dataSource
      .getRepository(Transaction)
      .createQueryBuilder('t')
      .select("to_char(date_trunc('day', t.createdAt), 'YYYY-MM-DD')", 'date')
      .addSelect('t.type', 'type')
      .addSelect('COALESCE(SUM(t.amount), 0)', 'total')
      .addSelect('COALESCE(SUM(t.costAmount), 0)', 'cost')
      .where('t.workspaceId = :workspaceId', { workspaceId: query.workspace_id })
      .andWhere('t.status = :status', { status: 'completed' })
      .andWhere('t.type IN (:...types)', { types: ['income', 'expense'] })
      .andWhere('t.createdAt >= :from', { from })
      .andWhere('t.createdAt < :to', { to })
      .groupBy("date_trunc('day', t.createdAt)")
      .addGroupBy('t.type')
      .orderBy("date_trunc('day', t.createdAt)", 'ASC')
      .getRawMany<{ date: string; type: 'income' | 'expense'; total: string; cost: string }>();

    const byDate = new Map<string, { income: number; expense: number; cost: number }>();
    for (const row of rows) {
      const entry = byDate.get(row.date) ?? { income: 0, expense: 0, cost: 0 };
      entry[row.type] = parseInt(row.total, 10) || 0;
      if (row.type === 'income') entry.cost = parseInt(row.cost, 10) || 0;
      byDate.set(row.date, entry);
    }

    // `profit` = doanh thu − giá vốn hàng bán − chi phí. When no cost was
    // ever recorded for a day's income, `cost` is 0 and this collapses to
    // the original income-minus-expense figure — see Transaction.costAmount
    // doc comment for why this is a safe, backward-compatible formula
    // change rather than a new/renamed field.
    return Array.from(byDate.entries())
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([date, { income, expense, cost }]) => ({ date, income, expense, cost, profit: income - cost - expense }));
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
