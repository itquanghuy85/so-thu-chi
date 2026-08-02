import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/screen_neutrals.dart';
import '../../../core/theme/section_accents.dart';
import '../../../core/theme/visual_style_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/providers/current_workspace_provider.dart';
import '../../../shared/widgets/section_app_bar.dart';
import '../../transaction/data/transaction_repository.dart';
import '../../transaction/domain/transaction.dart';
import '../../transaction/presentation/transaction_list_screen.dart' show TransactionTile, showTransactionDetailSheet;
import '../data/vault_repository.dart';
import '../domain/vault.dart';
import 'reconcile_sheet.dart';
import 'vault_list_screen.dart' show vaultTypeIcon;

/// Vault Detail (Mục 12.8): balance, a real 14-day balance trend derived
/// from that vault's own transactions (client-side running sum — the
/// backend has no per-vault balance-history endpoint), and the vault's
/// transaction history with a Kiểm kê shortcut.
class VaultDetailScreen extends ConsumerWidget {
  final Vault vault;

  const VaultDetailScreen({super.key, required this.vault});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(_vaultTransactionsProvider(vault.id));
    final color = AppColors.forKey(vault.id);
    final style = ref.watch(visualStyleProvider);
    final n = neutralsFor(style);
    final accent = sectionAccent(AppSection.vaults, style);

    return Scaffold(
      backgroundColor: n.tint(accent),
      appBar: SectionAppBar(
        title: vault.name,
        style: style,
        actions: [
          IconButton(
            tooltip: 'Xoá túi tiền',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteVault(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(_vaultTransactionsProvider(vault.id)),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(radius: 16, backgroundColor: Colors.white.withValues(alpha: 0.22), child: Icon(vaultTypeIcon(vault.type), color: Colors.white, size: 16)),
                      const SizedBox(width: 8),
                      Text(vaultTypeLabel(vault.type), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text('Số dư hiện tại', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(formatVND(vault.currentBalance), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Kiểm kê túi này'),
                onPressed: () async {
                  final done = await showReconcileFlow(context, ref);
                  if (done == true) ref.invalidate(_vaultTransactionsProvider(vault.id));
                },
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              decoration: n.cardDecoration(radius: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Biến động 14 ngày qua', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: n.textPrimary)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 130,
                    child: transactionsAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (error, _) => const SizedBox.shrink(),
                      data: (transactions) => _BalanceTrendChart(vault: vault, transactions: transactions, color: color, neutrals: n),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Lịch sử giao dịch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: n.textPrimary)),
            const SizedBox(height: 8),
            transactionsAsync.when(
              loading: () => Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: CircularProgressIndicator(color: n.isGame ? accent : null))),
              error: (error, _) => Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text('Không thể tải giao dịch', style: TextStyle(color: n.textSecondary))),
              data: (transactions) {
                if (transactions.isEmpty) {
                  return Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text('Chưa có giao dịch nào trên túi này.', style: TextStyle(color: n.textSecondary)));
                }
                return Column(
                  children: transactions
                      .map((t) => TransactionTile(transaction: t, onTap: () => showTransactionDetailSheet(context, ref, t)))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteVault(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xoá túi tiền?'),
        content: Text('Xoá "${vault.name}" vĩnh viễn. Nếu túi này đã từng có giao dịch, thao tác sẽ bị từ chối để không phá vỡ sổ sách.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Huỷ')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xoá', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(vaultRepositoryProvider).deleteVault(vault.id);
      ref.invalidate(vaultListProvider);
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      final message = e is ApiException ? e.message : 'Không thể xoá túi tiền';
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

final _vaultTransactionsProvider = FutureProvider.autoDispose.family<List<Transaction>, String>((ref, vaultId) async {
  final workspaceId = ref.watch(currentWorkspaceIdProvider);
  final page = await ref.watch(transactionRepositoryProvider).getTransactions(
        workspaceId: workspaceId,
        vaultId: vaultId,
        limit: 100,
      );
  return page.data;
});

class _BalanceTrendChart extends StatelessWidget {
  final Vault vault;
  final List<Transaction> transactions;
  final Color color;
  final ScreenNeutrals neutrals;

  const _BalanceTrendChart({required this.vault, required this.transactions, required this.color, required this.neutrals});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 13));

    // Walk backward from the current (known) balance, undoing each
    // transaction's effect on this vault to reconstruct a real historical
    // trend — not fabricated. `side` is inferred from transactionDisplay
    // sign conventions (D increases this vault's balance).
    num runningBalance = vault.currentBalance;
    final dayDeltas = List<num>.filled(14, 0);
    for (final t in transactions) {
      if (t.isVoided) continue;
      final dayIndex = DateTime(t.createdAt.year, t.createdAt.month, t.createdAt.day).difference(start).inDays;
      if (dayIndex < 0 || dayIndex > 13) continue;
      final increasesThisVault = (t.type == TransactionType.income && t.toVault?.id == vault.id) ||
          (t.type == TransactionType.transfer && t.toVault?.id == vault.id) ||
          (t.type == TransactionType.debtDecrease && t.toVault?.id == vault.id);
      dayDeltas[dayIndex] += increasesThisVault ? t.amount : -t.amount;
    }

    final balances = List<num>.filled(14, 0);
    var balance = runningBalance;
    for (var i = 13; i >= 0; i--) {
      balances[i] = balance;
      balance -= dayDeltas[i];
    }

    if (transactions.isEmpty) {
      return Center(child: Text('Chưa có dữ liệu', style: TextStyle(color: neutrals.textSecondary)));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(formatVND(s.y), const TextStyle(color: Colors.white, fontSize: 11)))
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [for (var i = 0; i < 14; i++) FlSpot(i.toDouble(), balances[i].toDouble())],
            isCurved: true,
            color: color,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.12)),
          ),
        ],
      ),
    );
  }
}
