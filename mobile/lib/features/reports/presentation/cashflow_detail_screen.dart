import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/section_app_bar.dart';
import 'cashflow_detail_notifier.dart';
import '../domain/cashflow_report.dart';

/// Báo cáo dòng tiền detail (Mục 12.12 drill-down): period tabs, a bar
/// chart (income up / expense down, per bucket), the server-aggregated
/// summary, and a category breakdown — see cashflow_detail_notifier.dart
/// for what's real server data vs. client-side derived.
class CashflowDetailScreen extends ConsumerStatefulWidget {
  const CashflowDetailScreen({super.key});

  @override
  ConsumerState<CashflowDetailScreen> createState() => _CashflowDetailScreenState();
}

class _CashflowDetailScreenState extends ConsumerState<CashflowDetailScreen> {
  ReportPeriod? _period = ReportPeriod.month;
  DateTimeRange? _customRange;

  bool get _isCustom => _period == null;

  String get _chipLabel {
    if (_isCustom && _customRange != null) {
      return '${DateFormat('dd/MM').format(_customRange!.start)} - ${DateFormat('dd/MM').format(_customRange!.end)}';
    }
    return _period?.label ?? '';
  }

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
        ? ref.watch(customCashflowDetailProvider(_customRange!))
        : ref.watch(cashflowDetailProvider(_period ?? ReportPeriod.month));

    return Scaffold(
      backgroundColor: AppColors.tint(AppColors.reports),
      appBar: const SectionAppBar(title: 'Báo cáo dòng tiền', accent: AppColors.reports),
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
                        selectedColor: AppColors.reports,
                        labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontSize: 12),
                        backgroundColor: AppColors.surface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        side: BorderSide.none,
                      ),
                    );
                  }),
                  ChoiceChip(
                    avatar: const Icon(Icons.date_range, size: 15),
                    label: Text(_isCustom ? _chipLabel : 'Tùy chọn'),
                    selected: _isCustom,
                    onSelected: (_) => _pickCustomRange(),
                    selectedColor: AppColors.reports,
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
                    ref.invalidate(customCashflowDetailProvider(_customRange!));
                  } else {
                    ref.invalidate(cashflowDetailProvider(_period ?? ReportPeriod.month));
                  }
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: const [
                        _LegendDot(color: AppColors.income, label: 'Thu'),
                        SizedBox(width: 16),
                        _LegendDot(color: AppColors.expense, label: 'Chi'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(height: 220, child: _CashflowBarChart(buckets: data.buckets)),
                    const SizedBox(height: 20),
                    _SummaryCard(periodLabel: _summaryLabel, report: data.report),
                    const SizedBox(height: 20),
                    if (data.breakdown.isNotEmpty) ...[
                      const Text('Chi tiết', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 8),
                      ...data.breakdown.map((e) => _BreakdownTile(entry: e)),
                    ],
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

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _CashflowBarChart extends StatelessWidget {
  final List<ChartBucket> buckets;

  const _CashflowBarChart({required this.buckets});

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty || buckets.every((b) => b.income == 0 && b.expense == 0)) {
      return const Center(child: Text('Chưa có giao dịch trong kỳ này', style: TextStyle(color: AppColors.textSecondary)));
    }
    final maxVal = buckets.fold<num>(
      1,
      (m, b) => [m, b.income, b.expense].reduce((a, c) => a > c ? a : c),
    );
    // Thin out labels so a month's worth of daily bars doesn't overlap.
    final labelEvery = (buckets.length / 8).ceil().clamp(1, 100);

    return BarChart(
      BarChartData(
        maxY: maxVal.toDouble() * 1.15,
        minY: -maxVal.toDouble() * 1.15,
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
                '${b.label}\nThu: ${formatVND(b.income)}\nChi: ${formatVND(b.expense)}',
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
                toY: buckets[i].income.toDouble(),
                color: AppColors.income,
                width: 6,
                borderRadius: BorderRadius.zero,
              ),
              BarChartRodData(
                fromY: 0,
                toY: -buckets[i].expense.toDouble(),
                color: AppColors.expense,
                width: 6,
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
  final CashflowReport report;

  const _SummaryCard({required this.periodLabel, required this.report});

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
          _SummaryRow(icon: Icons.arrow_downward, label: 'Tổng thu', amount: report.totalIncome, color: AppColors.income),
          _SummaryRow(icon: Icons.arrow_upward, label: 'Tổng chi', amount: report.totalExpense, color: AppColors.expense),
          _SummaryRow(icon: Icons.swap_vert, label: 'Dòng tiền thuần', amount: report.netCashflow, color: AppColors.primary),
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

class _BreakdownTile extends StatelessWidget {
  final CategoryBreakdownEntry entry;

  const _BreakdownTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final color = entry.isIncome ? AppColors.income : AppColors.expense;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(entry.isIncome ? Icons.arrow_downward : Icons.arrow_upward, color: color, size: 18),
      ),
      title: Text(entry.label),
      trailing: Text(formatVND(entry.amount), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }
}
