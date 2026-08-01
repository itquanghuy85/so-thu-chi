/// `GET /reports/cashflow` response — real server-aggregated totals for a
/// fixed period (`this_week` | `this_month` | `this_year`, always relative
/// to "now"; the backend has no custom date-range support for this
/// endpoint).
class CashflowReport {
  final String period;
  final num totalIncome;
  final num totalExpense;
  final num netCashflow;

  const CashflowReport({
    required this.period,
    required this.totalIncome,
    required this.totalExpense,
    required this.netCashflow,
  });

  factory CashflowReport.fromJson(Map<String, dynamic> json) {
    return CashflowReport(
      period: json['period'] as String? ?? '',
      totalIncome: (json['total_income'] as num?) ?? 0,
      totalExpense: (json['total_expense'] as num?) ?? 0,
      netCashflow: (json['net_cashflow'] as num?) ?? 0,
    );
  }
}

/// One row of `GET /reports/daily-summary` (Mục — "tính lãi/lỗ hàng
/// ngày"): a real server-side GROUP BY per calendar day, not a client-side
/// approximation — see `ReportsService.dailySummary`'s doc comment on the
/// backend for why there's no separate snapshot table behind it.
class DailySummary {
  final DateTime date;
  final num income;
  final num expense;
  final num profit;

  const DailySummary({required this.date, required this.income, required this.expense, required this.profit});

  factory DailySummary.fromJson(Map<String, dynamic> json) {
    return DailySummary(
      date: DateTime.parse(json['date'] as String),
      income: (json['income'] as num?) ?? 0,
      expense: (json['expense'] as num?) ?? 0,
      profit: (json['profit'] as num?) ?? 0,
    );
  }
}

enum ReportPeriod { week, month, year }

extension ReportPeriodApi on ReportPeriod {
  String get apiValue => switch (this) {
        ReportPeriod.week => 'this_week',
        ReportPeriod.month => 'this_month',
        ReportPeriod.year => 'this_year',
      };

  String get label => switch (this) {
        ReportPeriod.week => 'Tuần',
        ReportPeriod.month => 'Tháng',
        ReportPeriod.year => 'Năm',
      };

  /// Start of the period, computed the same way as the backend
  /// (`reports.service.ts#resolvePeriodRange`) so client-side transaction
  /// fetches (for the chart / category breakdown) line up with the
  /// server-aggregated totals shown alongside them.
  DateTime startDate(DateTime now) {
    final startOfDay = DateTime(now.year, now.month, now.day);
    switch (this) {
      case ReportPeriod.week:
        final diffToMonday = startOfDay.weekday - DateTime.monday;
        return startOfDay.subtract(Duration(days: diffToMonday));
      case ReportPeriod.month:
        return DateTime(now.year, now.month, 1);
      case ReportPeriod.year:
        return DateTime(now.year, 1, 1);
    }
  }
}
