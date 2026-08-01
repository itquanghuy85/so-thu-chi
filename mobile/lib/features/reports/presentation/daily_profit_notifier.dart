import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/current_workspace_provider.dart';
import '../data/reports_repository.dart';
import '../domain/cashflow_report.dart';

/// A single day or (for longer ranges) month bucket in the profit chart —
/// months are pre-summed from the daily rows client-side, since the backend
/// endpoint always returns daily granularity (see `dailyProfitProvider`).
class ProfitBucket {
  final String label;
  final num income;
  final num expense;
  final num cost;

  const ProfitBucket({required this.label, required this.income, required this.expense, this.cost = 0});

  num get profit => income - cost - expense;
}

class DailyProfitData {
  final List<DailySummary> days; // gap-filled: one row per calendar day in range, zeros where no transactions
  final List<ProfitBucket> chartBuckets;
  final num totalIncome;
  final num totalExpense;
  final num totalCost;

  const DailyProfitData({
    required this.days,
    required this.chartBuckets,
    required this.totalIncome,
    required this.totalExpense,
    required this.totalCost,
  });

  num get totalProfit => totalIncome - totalCost - totalExpense;
}

/// Real per-day revenue/expense/profit (Mục — "tính lãi/lỗ hàng ngày"),
/// sourced entirely from `GET /reports/daily-summary` (a server-side GROUP
/// BY, not a client-side approximation from a capped transaction fetch —
/// contrast with `cashflow_detail_notifier.dart`'s category breakdown,
/// which still has to do that for lack of a category-grouped endpoint).
final dailyProfitProvider = FutureProvider.autoDispose.family<DailyProfitData, ReportPeriod>((ref, period) async {
  final workspaceId = ref.watch(currentWorkspaceIdProvider);
  final reportsRepo = ref.watch(reportsRepositoryProvider);
  final now = DateTime.now();
  final from = period.startDate(now);
  final rows = await reportsRepo.getDailySummary(workspaceId: workspaceId, fromDate: from, toDate: now);
  return _buildData(from, now, rows);
});

final customDailyProfitProvider = FutureProvider.autoDispose.family<DailyProfitData, DateTimeRange>((ref, range) async {
  final workspaceId = ref.watch(currentWorkspaceIdProvider);
  final reportsRepo = ref.watch(reportsRepositoryProvider);
  final rows = await reportsRepo.getDailySummary(workspaceId: workspaceId, fromDate: range.start, toDate: range.end);
  return _buildData(range.start, range.end, rows);
});

DailyProfitData _buildData(DateTime from, DateTime to, List<DailySummary> rows) {
  final byDate = {for (final r in rows) _dateKey(r.date): r};
  final fromDay = DateTime(from.year, from.month, from.day);
  final toDay = DateTime(to.year, to.month, to.day);
  final dayCount = toDay.difference(fromDay).inDays + 1;

  final days = List.generate(dayCount, (i) {
    final d = fromDay.add(Duration(days: i));
    return byDate[_dateKey(d)] ?? DailySummary(date: d, income: 0, expense: 0, cost: 0, profit: 0);
  });

  final totalIncome = days.fold<num>(0, (s, d) => s + d.income);
  final totalExpense = days.fold<num>(0, (s, d) => s + d.expense);
  final totalCost = days.fold<num>(0, (s, d) => s + d.cost);

  // More than ~45 days of daily bars would overlap illegibly — group by
  // month instead, same threshold as the cashflow chart.
  final chartBuckets = dayCount > 45
      ? _monthlyBuckets(days)
      : days.map((d) => ProfitBucket(label: '${d.date.day}/${d.date.month}', income: d.income, expense: d.expense, cost: d.cost)).toList();

  return DailyProfitData(days: days, chartBuckets: chartBuckets, totalIncome: totalIncome, totalExpense: totalExpense, totalCost: totalCost);
}

List<ProfitBucket> _monthlyBuckets(List<DailySummary> days) {
  final byMonth = <String, ProfitBucket>{};
  final order = <String>[];
  for (final d in days) {
    final key = '${d.date.year}-${d.date.month}';
    final existing = byMonth[key];
    if (existing == null) order.add(key);
    byMonth[key] = ProfitBucket(
      label: '${d.date.month}/${d.date.year}',
      income: (existing?.income ?? 0) + d.income,
      expense: (existing?.expense ?? 0) + d.expense,
      cost: (existing?.cost ?? 0) + d.cost,
    );
  }
  return order.map((k) => byMonth[k]!).toList();
}

String _dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';
