import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/current_workspace_provider.dart';
import '../../transaction/data/transaction_repository.dart';
import '../../transaction/domain/transaction.dart';
import '../data/reports_repository.dart';
import '../domain/cashflow_report.dart';

class CategoryBreakdownEntry {
  final String label;
  final num amount;
  final bool isIncome;

  const CategoryBreakdownEntry({required this.label, required this.amount, required this.isIncome});
}

/// One bucket of the bar chart (a day, for Tuần/Tháng; a month, for Năm).
class ChartBucket {
  final String label;
  final num income;
  final num expense;

  const ChartBucket({required this.label, required this.income, required this.expense});
}

class CashflowDetailData {
  final CashflowReport report;
  final List<ChartBucket> buckets;
  final List<CategoryBreakdownEntry> breakdown;

  const CashflowDetailData({required this.report, required this.buckets, required this.breakdown});
}

/// Fetches the server-aggregated totals (`GET /reports/cashflow`) plus a
/// same-period transaction batch used purely for the chart/category
/// breakdown (client-side bucketing — the backend only returns totals, not
/// a daily/category breakdown). Real data throughout, no fabricated
/// numbers; documented in mobile/README.md as a client-side simplification.
/// Keyed by [ReportPeriod] so the Reports overview (always "month", for its
/// mini preview chart) and the Cashflow detail screen (user-selectable) can
/// both read this without stepping on each other.
final cashflowDetailProvider =
    FutureProvider.autoDispose.family<CashflowDetailData, ReportPeriod>((ref, period) async {
  final workspaceId = ref.watch(currentWorkspaceIdProvider);
  final reportsRepo = ref.watch(reportsRepositoryProvider);
  final transactionRepo = ref.watch(transactionRepositoryProvider);

  final now = DateTime.now();
  final from = period.startDate(now);

  final results = await Future.wait([
    reportsRepo.getCashflow(workspaceId: workspaceId, period: period),
    transactionRepo.getTransactions(
      workspaceId: workspaceId,
      fromDate: from,
      toDate: now,
      page: 1,
      limit: 300,
    ),
  ]);
  final report = results[0] as CashflowReport;
  final page = results[1] as TransactionPage;
  final transactions = page.data.where((t) => !t.isVoided && (t.type == TransactionType.income || t.type == TransactionType.expense));

  final buckets = _buildBuckets(period, from, now, transactions);
  final breakdown = _buildBreakdown(transactions);

  return CashflowDetailData(report: report, buckets: buckets, breakdown: breakdown);
});

/// Custom date-range variant ("Tùy chọn"): `GET /reports/cashflow` only
/// supports the 3 fixed periods above, so for an arbitrary range the
/// summary totals are computed client-side from the same fetched
/// transaction batch as the chart/breakdown — still real data, just not
/// server-aggregated. Documented in mobile/README.md.
final customCashflowDetailProvider =
    FutureProvider.autoDispose.family<CashflowDetailData, DateTimeRange>((ref, range) async {
  final workspaceId = ref.watch(currentWorkspaceIdProvider);
  final transactionRepo = ref.watch(transactionRepositoryProvider);

  final from = DateTime(range.start.year, range.start.month, range.start.day);
  final to = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);

  final page = await transactionRepo.getTransactions(
    workspaceId: workspaceId,
    fromDate: from,
    toDate: to,
    page: 1,
    limit: 300,
  );
  final transactions =
      page.data.where((t) => !t.isVoided && (t.type == TransactionType.income || t.type == TransactionType.expense));

  final totalIncome = transactions.where((t) => t.type == TransactionType.income).fold<num>(0, (s, t) => s + t.amount);
  final totalExpense = transactions.where((t) => t.type == TransactionType.expense).fold<num>(0, (s, t) => s + t.amount);
  final totalCost = transactions
      .where((t) => t.type == TransactionType.income)
      .fold<num>(0, (s, t) => s + (t.costAmount ?? 0));

  final spanDays = to.difference(from).inDays + 1;
  final buckets = spanDays > 45 ? _buildMonthlyBuckets(from, to, transactions) : _buildDailyBuckets(from, to, transactions);
  final breakdown = _buildBreakdown(transactions);

  return CashflowDetailData(
    report: CashflowReport(
      period: 'custom',
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      netCashflow: totalIncome - totalExpense,
      totalCost: totalCost,
      grossProfit: totalIncome - totalCost - totalExpense,
    ),
    buckets: buckets,
    breakdown: breakdown,
  );
});

List<ChartBucket> _buildDailyBuckets(DateTime from, DateTime to, Iterable<Transaction> transactions) {
  final days = DateTime(to.year, to.month, to.day).difference(from).inDays + 1;
  return List.generate(days, (i) {
    final day = from.add(Duration(days: i));
    final income = transactions.where((t) => t.type == TransactionType.income && _isSameDay(t.createdAt, day)).fold<num>(0, (s, t) => s + t.amount);
    final expense = transactions.where((t) => t.type == TransactionType.expense && _isSameDay(t.createdAt, day)).fold<num>(0, (s, t) => s + t.amount);
    return ChartBucket(label: '${day.day}/${day.month}', income: income, expense: expense);
  });
}

List<ChartBucket> _buildMonthlyBuckets(DateTime from, DateTime to, Iterable<Transaction> transactions) {
  final buckets = <ChartBucket>[];
  var cursor = DateTime(from.year, from.month);
  while (!cursor.isAfter(to)) {
    final income = transactions
        .where((t) => t.type == TransactionType.income && t.createdAt.year == cursor.year && t.createdAt.month == cursor.month)
        .fold<num>(0, (s, t) => s + t.amount);
    final expense = transactions
        .where((t) => t.type == TransactionType.expense && t.createdAt.year == cursor.year && t.createdAt.month == cursor.month)
        .fold<num>(0, (s, t) => s + t.amount);
    buckets.add(ChartBucket(label: '${cursor.month}/${cursor.year}', income: income, expense: expense));
    cursor = DateTime(cursor.year, cursor.month + 1);
  }
  return buckets;
}

List<ChartBucket> _buildBuckets(ReportPeriod period, DateTime from, DateTime now, Iterable<Transaction> transactions) {
  if (period == ReportPeriod.year) {
    final months = List.generate(now.month, (i) => i + 1);
    return months.map((m) {
      final income = transactions
          .where((t) => t.type == TransactionType.income && t.createdAt.month == m && t.createdAt.year == now.year)
          .fold<num>(0, (s, t) => s + t.amount);
      final expense = transactions
          .where((t) => t.type == TransactionType.expense && t.createdAt.month == m && t.createdAt.year == now.year)
          .fold<num>(0, (s, t) => s + t.amount);
      return ChartBucket(label: 'Th$m', income: income, expense: expense);
    }).toList();
  }

  // Tuần / Tháng: one bucket per day from `from` to `now`.
  final days = now.difference(DateTime(from.year, from.month, from.day)).inDays + 1;
  return List.generate(days, (i) {
    final day = DateTime(from.year, from.month, from.day).add(Duration(days: i));
    final income = transactions
        .where((t) => t.type == TransactionType.income && _isSameDay(t.createdAt, day))
        .fold<num>(0, (s, t) => s + t.amount);
    final expense = transactions
        .where((t) => t.type == TransactionType.expense && _isSameDay(t.createdAt, day))
        .fold<num>(0, (s, t) => s + t.amount);
    return ChartBucket(label: '${day.day}/${day.month}', income: income, expense: expense);
  });
}

bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

List<CategoryBreakdownEntry> _buildBreakdown(Iterable<Transaction> transactions) {
  final totals = <String, CategoryBreakdownEntry>{};
  for (final t in transactions) {
    final isIncome = t.type == TransactionType.income;
    final label = t.category?.name ?? (isIncome ? 'Thu khác' : 'Chi khác');
    final key = '${isIncome ? 'in' : 'out'}:$label';
    final existing = totals[key];
    totals[key] = CategoryBreakdownEntry(
      label: label,
      amount: (existing?.amount ?? 0) + t.amount,
      isIncome: isIncome,
    );
  }
  final list = totals.values.toList()..sort((a, b) => b.amount.compareTo(a.amount));
  return list.take(8).toList();
}
