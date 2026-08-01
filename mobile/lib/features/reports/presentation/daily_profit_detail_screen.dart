import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../domain/cashflow_report.dart';
import 'daily_profit_notifier.dart';

/// "Báo cáo doanh thu, lợi nhuận" (Mục — daily profit/loss): period tabs
/// (Tuần/Tháng/Năm/Tùy chọn), a per-day (or per-month, for long ranges)
/// profit bar chart, and a full data table — every number here comes
/// straight from `GET /reports/daily-summary`, a real server aggregation.
class DailyProfitDetailScreen extends ConsumerStatefulWidget {
  const DailyProfitDetailScreen({super.key});

  @override
  ConsumerState<DailyProfitDetailScreen> createState() => _DailyProfitDetailScreenState();
}

class _DailyProfitDetailScreenState extends ConsumerState<DailyProfitDetailScreen> {
  ReportPeriod? _period = ReportPeriod.month;
  DateTimeRange? _customRange;

  bool get _isCustom => _period == null;

  String get _summaryLabel {
    if (_isCustom && _customRange != null) {
      return 'từ ${DateFormat('dd/MM/yyyy').format(_customRange!.start)} đến ${DateFormat('dd/MM/yyyy').format(_customRange!.end)}';
    }
    return '${(_period ?? ReportPeriod.month).label.toLowerCase()} này';
  }

  Future<void> _pickCustomRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customRange,
    );
    if (range == null) return;
    setState(() {
      _period = null;
      _customRange = range;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = _isCustom && _customRange != null
        ? ref.watch(customDailyProfitProvider(_customRange!))
        : ref.watch(dailyProfitProvider(_period ?? ReportPeriod.month));

    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo lợi nhuận')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...ReportPeriod.values.map((p) {
                    final selected = !_isCustom && _period == p;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(p.label),
                        selected: selected,
                        onSelected: (_) => setState(() => _period = p),
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontSize: 12),
                        backgroundColor: AppColors.surface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        side: BorderSide.none,
                      ),
                    );
                  }),
                  ChoiceChip(
                    avatar: const Icon(Icons.date_range, size: 15),
                    label: Text(_isCustom && _customRange != null
                        ? '${DateFormat('dd/MM').format(_customRange!.start)} - ${DateFormat('dd/MM').format(_customRange!.end)}'
                        : 'Tùy chọn'),
                    selected: _isCustom,
                    onSelected: (_) => _pickCustomRange(),
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(color: _isCustom ? Colors.white : AppColors.textPrimary, fontSize: 12),
                    backgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    side: BorderSide.none,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: dataAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => const Center(child: Text('Không thể tải báo cáo')),
              data: (data) => RefreshIndicator(
                onRefresh: () async {
                  if (_isCustom && _customRange != null) {
                    ref.invalidate(customDailyProfitProvider(_customRange!));
                  } else {
                    ref.invalidate(dailyProfitProvider(_period ?? ReportPeriod.month));
                  }
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SizedBox(height: 220, child: _ProfitBarChart(buckets: data.chartBuckets)),
                    const SizedBox(height: 20),
                    _SummaryCard(periodLabel: _summaryLabel, data: data),
                    const SizedBox(height: 20),
                    const Text('Chi tiết theo ngày', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    _DailyProfitTable(days: data.days),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfitBarChart extends StatelessWidget {
  final List<ProfitBucket> buckets;

  const _ProfitBarChart({required this.buckets});

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty || buckets.every((b) => b.income == 0 && b.expense == 0)) {
      return const Center(child: Text('Chưa có giao dịch trong kỳ này', style: TextStyle(color: AppColors.textSecondary)));
    }
    final maxVal = buckets.fold<num>(1, (m, b) => b.profit.abs() > m ? b.profit.abs() : m);
    final labelEvery = (buckets.length / 8).ceil().clamp(1, 100);

    return BarChart(
      BarChartData(
        maxY: maxVal.toDouble() * 1.2,
        minY: -maxVal.toDouble() * 1.2,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= buckets.length || i % labelEvery != 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(buckets[i].label, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final b = buckets[group.x.toInt()];
              return BarTooltipItem(
                '${b.label}\nLợi nhuận: ${formatVND(b.profit)}',
                const TextStyle(color: Colors.white, fontSize: 11),
              );
            },
          ),
        ),
        barGroups: [
          for (var i = 0; i < buckets.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                fromY: 0,
                toY: buckets[i].profit.toDouble(),
                color: buckets[i].profit >= 0 ? AppColors.income : AppColors.expense,
                width: 8,
                borderRadius: BorderRadius.zero,
              ),
            ]),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String periodLabel;
  final DailyProfitData data;

  const _SummaryCard({required this.periodLabel, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tổng quan $periodLabel', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          _SummaryRow(icon: Icons.arrow_downward, label: 'Tổng doanh thu', amount: data.totalIncome, color: AppColors.income),
          _SummaryRow(icon: Icons.arrow_upward, label: 'Tổng chi phí', amount: data.totalExpense, color: AppColors.expense),
          _SummaryRow(
            icon: data.totalProfit >= 0 ? Icons.trending_up : Icons.trending_down,
            label: 'Lợi nhuận',
            amount: data.totalProfit,
            color: data.totalProfit >= 0 ? AppColors.primary : AppColors.error,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final num amount;
  final Color color;

  const _SummaryRow({required this.icon, required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(radius: 15, backgroundColor: color.withValues(alpha: 0.12), child: Icon(icon, size: 15, color: color)),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text(formatVND(amount), style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _DailyProfitTable extends StatelessWidget {
  final List<DailySummary> days;

  const _DailyProfitTable({required this.days});

  @override
  Widget build(BuildContext context) {
    // Newest first, and skip zero-activity days so a month-long table
    // doesn't drown the days that actually had transactions.
    final rows = days.reversed.where((d) => d.income != 0 || d.expense != 0).toList();
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('Chưa có ngày nào có giao dịch', style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 40,
          dataRowMinHeight: 40,
          dataRowMaxHeight: 44,
          columns: const [
            DataColumn(label: Text('Ngày')),
            DataColumn(label: Text('Thu'), numeric: true),
            DataColumn(label: Text('Chi'), numeric: true),
            DataColumn(label: Text('Lãi/Lỗ'), numeric: true),
          ],
          rows: rows
              .map((d) => DataRow(cells: [
                    DataCell(Text(DateFormat('dd/MM/yyyy').format(d.date))),
                    DataCell(Text(formatVND(d.income), style: const TextStyle(color: AppColors.income))),
                    DataCell(Text(formatVND(d.expense), style: const TextStyle(color: AppColors.expense))),
                    DataCell(Text(
                      formatVND(d.profit),
                      style: TextStyle(color: d.profit >= 0 ? AppColors.primary : AppColors.error, fontWeight: FontWeight.bold),
                    )),
                  ]))
              .toList(),
        ),
      ),
    );
  }
}
