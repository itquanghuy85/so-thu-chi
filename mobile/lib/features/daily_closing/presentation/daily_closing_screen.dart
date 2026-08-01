import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/providers/current_workspace_provider.dart';
import '../../../shared/widgets/amount_text_field.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../vault/data/vault_repository.dart';
import '../data/daily_closing_repository.dart';
import '../domain/daily_closing.dart';

/// "Chốt sổ cuối ngày" (Mục — daily closing): once per calendar day, counts
/// every vault's actual balance against the ledger's book balance. Reuses
/// the same per-vault "Kiểm kê" reconcile action server-side — this screen
/// is the once-a-day, all-vaults-at-once wrapper around it, plus history.
class DailyClosingScreen extends ConsumerWidget {
  const DailyClosingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(dailyClosingTodayProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Chốt sổ cuối ngày')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dailyClosingTodayProvider);
          ref.invalidate(dailyClosingHistoryProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            todayAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    const Text('Không thể tải trạng thái chốt sổ'),
                    const SizedBox(height: 8),
                    OutlinedButton(onPressed: () => ref.invalidate(dailyClosingTodayProvider), child: const Text('Thử lại')),
                  ],
                ),
              ),
              data: (closing) => closing != null ? _ClosedTodayCard(closing: closing) : const _CloseTodayForm(),
            ),
            const SizedBox(height: 24),
            const Text('Lịch sử chốt sổ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            Consumer(
              builder: (context, ref, _) {
                final historyAsync = ref.watch(dailyClosingHistoryProvider);
                return historyAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => const Text('Không thể tải lịch sử'),
                  data: (items) {
                    if (items.isEmpty) {
                      return const EmptyStateWidget(icon: Icons.fact_check_outlined, message: 'Chưa có lần chốt sổ nào.');
                    }
                    return Column(children: items.map((c) => _ClosingHistoryTile(closing: c)).toList());
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CloseTodayForm extends ConsumerStatefulWidget {
  const _CloseTodayForm();

  @override
  ConsumerState<_CloseTodayForm> createState() => _CloseTodayFormState();
}

class _CloseTodayFormState extends ConsumerState<_CloseTodayForm> {
  final _controllers = <String, TextEditingController>{};
  final _noteController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _close(String workspaceId) async {
    setState(() => _saving = true);
    try {
      final entries = _controllers.entries
          .map((e) => (vaultId: e.key, actualBalance: parseCurrencyInput(e.value.text)))
          .toList();
      await ref.read(dailyClosingRepositoryProvider).close(
            workspaceId: workspaceId,
            entries: entries,
            note: _noteController.text.trim(),
          );
      ref.invalidate(dailyClosingTodayProvider);
      ref.invalidate(dailyClosingHistoryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã chốt sổ hôm nay')));
      }
    } catch (e) {
      final message = e is ApiException ? e.message : 'Không thể chốt sổ';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspaceId = ref.watch(currentWorkspaceIdProvider);
    final vaultsAsync = ref.watch(vaultListProvider);

    return vaultsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => const Text('Không thể tải danh sách túi tiền'),
      data: (vaults) {
        if (vaults.isEmpty) {
          return const EmptyStateWidget(icon: Icons.account_balance_wallet_outlined, message: 'Chưa có túi tiền để chốt sổ.');
        }
        for (final v in vaults) {
          _controllers.putIfAbsent(v.id, () => TextEditingController(text: formatVND(v.currentBalance).replaceAll('đ', '')));
        }
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Đếm số dư thực tế từng túi tiền', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 4),
              const Text(
                'Hệ thống sẽ so sánh với số dư sổ sách và ghi nhận chênh lệch (nếu có).',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ...vaults.map((v) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AmountTextField(controller: _controllers[v.id]!, label: '${v.name} (sổ sách: ${formatVND(v.currentBalance)})'),
                  )),
              TextField(
                controller: _noteController,
                decoration: InputDecoration(labelText: 'Ghi chú (không bắt buộc)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.fact_check_outlined),
                  label: _saving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Chốt sổ hôm nay'),
                  onPressed: _saving ? null : () => _close(workspaceId),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ClosedTodayCard extends StatelessWidget {
  final DailyClosing closing;

  const _ClosedTodayCard({required this.closing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: AppColors.headerGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text('Đã chốt sổ hôm nay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Bởi ${closing.closedByName} lúc ${DateFormat('HH:mm').format(closing.createdAt)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 12),
          ...closing.entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(e.name, style: const TextStyle(color: Colors.white, fontSize: 12))),
                    Text(
                      e.variance == 0 ? 'Khớp sổ sách' : '${e.variance > 0 ? '+' : ''}${formatVND(e.variance)}',
                      style: TextStyle(color: e.variance == 0 ? Colors.white : Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              )),
          if (closing.note != null && closing.note!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(closing.note!, style: const TextStyle(color: Colors.white70, fontSize: 11, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }
}

class _ClosingHistoryTile extends StatelessWidget {
  final DailyClosing closing;

  const _ClosingHistoryTile({required this.closing});

  @override
  Widget build(BuildContext context) {
    final color = closing.totalVariance == 0 ? AppColors.income : AppColors.error;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(DateFormat('dd/MM/yyyy').format(DateTime.parse(closing.closingDate)), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 2),
                Text('${closing.entries.length} túi tiền • ${closing.closedByName}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text(
            closing.totalVariance == 0 ? 'Khớp' : '${closing.totalVariance > 0 ? '+' : ''}${formatVND(closing.totalVariance)}',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
