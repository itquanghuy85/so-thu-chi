import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/export/excel_export_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/section_app_bar.dart';
import '../../debt/data/customer_repository.dart';
import '../../vault/data/vault_repository.dart';
import '../domain/cashflow_report.dart';
import 'cashflow_detail_notifier.dart';
import 'cashflow_detail_screen.dart';
import 'daily_profit_detail_screen.dart';

/// Tab Báo cáo (Mục 12.12) overview grid. Every tile is backed by real
/// data already available from other endpoints — nothing fabricated:
/// - Dòng tiền → `GET /reports/cashflow` (drills into [CashflowDetailScreen]).
/// - Lợi nhuận → `GET /reports/daily-summary`, a real per-day server
///   aggregation (drills into [DailyProfitDetailScreen]) — "profit" here is
///   income − expense; there's still no separate cost-of-goods tracking in
///   this MVP pass, so it isn't gross margin in the accounting sense.
/// - Tổng tài sản → sum of vault balances (same source as the Dashboard).
/// - Công nợ → sum of customer debt balances (same source as the Debt tab).
class ReportsOverviewScreen extends ConsumerWidget {
  const ReportsOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthReportAsync = ref.watch(cashflowDetailProvider(ReportPeriod.month));
    final vaultsAsync = ref.watch(vaultListProvider);
    final customersAsync = ref.watch(customerListProvider);

    final totalAssets = vaultsAsync.maybeWhen(
      data: (vaults) => vaults.fold<num>(0, (s, v) => s + v.currentBalance),
      orElse: () => null,
    );
    final totalDebt = customersAsync.maybeWhen(
      data: (customers) => customers.fold<num>(0, (s, c) => s + c.debtBalance),
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: AppColors.tint(AppColors.reports),
      appBar: SectionAppBar(
        title: 'Báo cáo',
        accent: AppColors.reports,
        actions: [
          IconButton(
            tooltip: 'Xuất Excel',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () async {
              final report = monthReportAsync.valueOrNull?.report;
              if (report == null || totalAssets == null || totalDebt == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dữ liệu chưa sẵn sàng, vui lòng thử lại')));
                return;
              }
              await excelExportService.exportSummaryReport(
                report: report,
                totalAssets: totalAssets,
                totalDebt: totalDebt,
                periodLabel: 'Tháng ${DateTime.now().month}-${DateTime.now().year}',
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(cashflowDetailProvider(ReportPeriod.month));
          ref.invalidate(vaultListProvider);
          ref.invalidate(customerListProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Tổng quan báo cáo tài chính', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: [
                _ReportTile(
                  title: 'Dòng tiền',
                  subtitle: 'Thu chi, dòng tiền theo thời gian',
                  icon: Icons.attach_money,
                  gradient: AppColors.reportCashflow,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CashflowDetailScreen()),
                  ),
                ),
                _ReportTile(
                  title: 'Lợi nhuận',
                  subtitle: 'Lãi/lỗ theo ngày, tuần, tháng, năm',
                  icon: Icons.show_chart,
                  gradient: AppColors.reportProfit,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DailyProfitDetailScreen()),
                  ),
                ),
                _ReportTile(
                  title: 'Tổng tài sản',
                  subtitle: 'Tài sản, vốn theo túi tiền',
                  icon: Icons.account_balance_wallet,
                  gradient: AppColors.reportNetWorth,
                  onTap: () => context.go('/vaults'),
                ),
                _ReportTile(
                  title: 'Công nợ',
                  subtitle: 'Phải thu, quá hạn',
                  icon: Icons.receipt_long,
                  gradient: AppColors.reportDebt,
                  onTap: () => context.go('/debt'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tổng quan tháng này', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  monthReportAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    error: (error, _) => const Text('Không thể tải báo cáo', style: TextStyle(color: AppColors.textSecondary)),
                    data: (data) => Column(
                      children: [
                        _OverviewRow(icon: Icons.arrow_downward, label: 'Tổng thu', amount: data.report.totalIncome, color: AppColors.income),
                        _OverviewRow(icon: Icons.arrow_upward, label: 'Tổng chi', amount: data.report.totalExpense, color: AppColors.expense),
                        _OverviewRow(icon: Icons.trending_up, label: 'Lợi nhuận', amount: data.report.netCashflow, color: AppColors.primary),
                        if (totalDebt != null)
                          _OverviewRow(icon: Icons.receipt_long, label: 'Công nợ phải thu', amount: totalDebt, color: AppColors.debt),
                        if (totalAssets != null)
                          _OverviewRow(icon: Icons.account_balance_wallet, label: 'Tổng tài sản', amount: totalAssets, color: AppColors.secondary),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Dòng tiền thuần (tháng này)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 140,
                    child: monthReportAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (error, _) => const SizedBox.shrink(),
                      data: (data) => _MiniNetLineChart(buckets: data.buckets),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _ReportTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white.withValues(alpha: 0.22),
                child: Icon(icon, color: Colors.white, size: 17),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final num amount;
  final Color color;

  const _OverviewRow({required this.icon, required this.label, required this.amount, required this.color});

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

class _MiniNetLineChart extends StatelessWidget {
  final List<ChartBucket> buckets;

  const _MiniNetLineChart({required this.buckets});

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty) {
      return const Center(child: Text('Chưa có dữ liệu', style: TextStyle(color: AppColors.textSecondary)));
    }
    final spots = <FlSpot>[];
    num cumulative = 0;
    for (var i = 0; i < buckets.length; i++) {
      cumulative += buckets[i].income - buckets[i].expense;
      spots.add(FlSpot(i.toDouble(), cumulative.toDouble()));
    }
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.12)),
          ),
        ],
      ),
    );
  }
}
