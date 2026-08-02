import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/export/excel_export_service.dart';
import '../../../core/offline/sync_queue_service.dart';
import '../../../core/theme/screen_neutrals.dart';
import '../../../core/theme/section_accents.dart';
import '../../../core/theme/visual_style_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/providers/current_workspace_provider.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/section_app_bar.dart';
import '../../../shared/widgets/sheet_drag_handle.dart';
import '../data/transaction_repository.dart';
import '../domain/transaction.dart';
import 'create_transaction_sheet.dart';
import 'edit_transaction_sheet.dart';
import 'transaction_display.dart';
import 'transaction_list_notifier.dart';

class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({super.key});

  @override
  ConsumerState<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(transactionListProvider.notifier).loadNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionListProvider);
    final notifier = ref.read(transactionListProvider.notifier);
    final style = ref.watch(visualStyleProvider);
    final n = neutralsFor(style);
    final accent = sectionAccent(AppSection.transactions, style);

    return Scaffold(
      backgroundColor: n.tint(accent),
      appBar: SectionAppBar(
        title: 'Giao dịch',
        style: style,
        actions: [
          IconButton(
            tooltip: 'Xuất Excel',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () => _exportToExcel(context, ref, state.filter),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: TransactionPeriodFilter.values.map((p) {
                  final selected = state.filter.period == p;
                  final label = p == TransactionPeriodFilter.custom && selected && state.filter.customRange != null
                      ? '${DateFormat('dd/MM').format(state.filter.customRange!.start)} - ${DateFormat('dd/MM').format(state.filter.customRange!.end)}'
                      : p.label;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: selected,
                      onSelected: (_) async {
                        if (p == TransactionPeriodFilter.custom) {
                          final range = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                            initialDateRange: state.filter.customRange,
                          );
                          if (range == null) return;
                          notifier.setFilter(state.filter.copyWith(period: p, customRange: range));
                        } else {
                          notifier.setFilter(state.filter.copyWith(period: p));
                        }
                      },
                      selectedColor: accent,
                      labelStyle: TextStyle(color: selected ? Colors.white : n.textPrimary, fontSize: 12),
                      backgroundColor: n.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      side: n.isGame ? BorderSide(color: n.divider) : BorderSide.none,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _TypeChip(label: 'Loại', selected: state.filter.type == null, icon: Icons.filter_list, neutrals: n, onTap: () => notifier.setFilter(state.filter.copyWith(clearType: true))),
                  const SizedBox(width: 8),
                  _TypeChip(label: 'Thu', selected: state.filter.type == TransactionType.income, color: transactionColor(TransactionType.income, style), neutrals: n, onTap: () => notifier.setFilter(state.filter.copyWith(type: TransactionType.income))),
                  const SizedBox(width: 8),
                  _TypeChip(label: 'Chi', selected: state.filter.type == TransactionType.expense, color: transactionColor(TransactionType.expense, style), neutrals: n, onTap: () => notifier.setFilter(state.filter.copyWith(type: TransactionType.expense))),
                  const SizedBox(width: 8),
                  _TypeChip(label: 'Chuyển', selected: state.filter.type == TransactionType.transfer, color: transactionColor(TransactionType.transfer, style), neutrals: n, onTap: () => notifier.setFilter(state.filter.copyWith(type: TransactionType.transfer))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Builder(builder: (context) {
              if (state.isLoading && state.items.isEmpty) {
                return Center(child: CircularProgressIndicator(color: n.isGame ? accent : null));
              }
              if (state.errorMessage != null && state.items.isEmpty) {
                return Center(child: Text(state.errorMessage!, style: TextStyle(color: n.textPrimary)));
              }
              if (state.items.isEmpty) {
                return EmptyStateWidget(
                  message: 'Không có giao dịch nào trong bộ lọc này.',
                  icon: Icons.receipt_long_outlined,
                  accent: accent,
                );
              }
              return RefreshIndicator(
                onRefresh: () => notifier.loadFirstPage(),
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: state.items.length + (state.hasMore ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    if (index >= state.items.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    }
                    final transaction = state.items[index];
                    return TransactionTile(
                      transaction: transaction,
                      onTap: () => showTransactionDetailSheet(context, ref, transaction),
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        onPressed: () async {
          final created = await showCreateTransactionSheet(context);
          if (created == true) {
            notifier.loadFirstPage();
            ref.invalidate(pendingSyncCountProvider);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Fetches every page matching the currently active filter (not just what
  /// happens to be scrolled into view) and exports it to Excel.
  ///
  /// Deliberately avoids a modal `showDialog` + `Navigator.pop()` combo for
  /// the in-progress indicator: popping a dialog from a stored outer
  /// `context` after a long `await` (here, spanning the OS share sheet
  /// launching via `Share.shareXFiles`) can race with unrelated navigation
  /// events and hit Flutter's `!_debugLocked` assertion — observed crashing
  /// live. A SnackBar has no such navigation-stack interaction.
  Future<void> _exportToExcel(BuildContext context, WidgetRef ref, TransactionListFilter filter) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Đang tạo file Excel...'), duration: Duration(seconds: 30)));
    try {
      final repo = ref.read(transactionRepositoryProvider);
      final workspaceId = ref.read(currentWorkspaceIdProvider);
      final all = <Transaction>[];
      var page = 1;
      var totalPages = 1;
      do {
        final result = await repo.getTransactions(
          workspaceId: workspaceId,
          type: filter.type == null ? null : transactionTypeToString(filter.type!),
          fromDate: filter.effectiveFromDate,
          toDate: filter.effectiveToDate,
          page: page,
          limit: 100,
        );
        all.addAll(result.data);
        totalPages = result.totalPages;
        page++;
      } while (page <= totalPages);

      messenger.hideCurrentSnackBar();
      if (all.isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text('Không có giao dịch để xuất')));
        return;
      }
      final path = await excelExportService.exportTransactions(transactions: all, periodLabel: filter.period.label);
      messenger.showSnackBar(SnackBar(
        content: Text('Đã lưu file Excel vào $path'),
        duration: const Duration(seconds: 5),
      ));
    } catch (e) {
      messenger.hideCurrentSnackBar();
      final message = e is ApiException ? e.message : 'Không thể xuất file Excel';
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final IconData? icon;
  final ScreenNeutrals neutrals;
  final VoidCallback onTap;

  const _TypeChip({required this.label, required this.selected, this.color, this.icon, required this.neutrals, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? neutrals.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? chipColor.withValues(alpha: 0.14) : neutrals.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? chipColor : neutrals.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 14, color: selected ? chipColor : neutrals.textSecondary), const SizedBox(width: 4)],
            Text(label, style: TextStyle(fontSize: 12, color: selected ? chipColor : neutrals.textSecondary, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}

class TransactionTile extends ConsumerWidget {
  final Transaction transaction;
  final VoidCallback? onTap;

  const TransactionTile({super.key, required this.transaction, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(visualStyleProvider);
    final n = neutralsFor(style);
    final color = transactionColor(transaction.type, style);
    final pendingColor = transactionColor(TransactionType.transfer, style);
    final profitColor = transactionColor(TransactionType.income, style);
    final lossColor = transactionColor(TransactionType.expense, style);
    final timeFormat = DateFormat('HH:mm dd/MM/yyyy', 'vi_VN');
    final isVoided = transaction.isVoided;
    final profit = transaction.profit;

    // Category/transfer-arrow description, plus the vault it landed in/out
    // of when that's not already implied (transfer already names both
    // vaults; debt types fold the note into the description instead).
    final vaultName = switch (transaction.type) {
      TransactionType.income => transaction.toVault?.name,
      TransactionType.expense => transaction.fromVault?.name,
      _ => null,
    };
    final description = transactionDescription(transaction);
    final descriptionLine = [description, if (vaultName != null && vaultName != description) vaultName]
        .where((s) => s.isNotEmpty)
        .join(' • ');
    final showNoteLine = (transaction.note ?? '').isNotEmpty &&
        transaction.type != TransactionType.debtIncrease &&
        transaction.type != TransactionType.debtDecrease;
    final metaLine = [timeFormat.format(transaction.createdAt), if (transaction.createdBy != null) transaction.createdBy!.name]
        .join(' • ');

    return Opacity(
      opacity: isVoided ? 0.5 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: n.cardDecoration(accent: n.isGame ? color : null),
        child: ListTile(
          onTap: onTap,
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(transactionIcon(transaction.type), color: color, size: 20),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  transactionTypeLabel(transaction.type) + (isVoided ? ' (đã hủy)' : ''),
                  style: TextStyle(fontWeight: FontWeight.w600, color: n.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (transaction.pending) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: pendingColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Chờ đồng bộ', style: TextStyle(fontSize: 10, color: pendingColor, fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (descriptionLine.isNotEmpty)
                Text(descriptionLine, style: TextStyle(color: n.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (showNoteLine)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    transaction.note!,
                    style: TextStyle(color: n.textSecondary, fontStyle: FontStyle.italic, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(metaLine, style: TextStyle(color: n.textSecondary, fontSize: 11)),
              ),
            ],
          ),
          trailing: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${transactionAmountSign(transaction.type)}${formatVND(transaction.amount)}',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              if (profit != null) ...[
                const SizedBox(height: 2),
                Text(
                  '${profit >= 0 ? 'Lãi ' : 'Lỗ '}${formatVND(profit.abs())}',
                  style: TextStyle(color: profit >= 0 ? profitColor : lossColor, fontWeight: FontWeight.w600, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet showing transaction detail (Mục 12.5.1) with a "Hủy giao
/// dịch" action when the transaction is still active.
void showTransactionDetailSheet(BuildContext context, WidgetRef ref, Transaction transaction) {
  final style = ref.read(visualStyleProvider);
  final color = transactionColor(transaction.type, style);
  final n = neutralsFor(style);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: n.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) {
      final dateFormat = DateFormat('HH:mm, dd/MM/yyyy', 'vi_VN');
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: SheetDragHandle()),
              const SizedBox(height: 8),
              Center(
                child: CircleAvatar(radius: 26, backgroundColor: color.withValues(alpha: 0.12), child: Icon(transactionIcon(transaction.type), color: color)),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  '${transactionAmountSign(transaction.type)}${formatVND(transaction.amount)}',
                  style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              Center(
                child: Text(
                  transactionTypeLabel(transaction.type) + (transaction.isVoided ? ' • Đã hủy' : ''),
                  style: TextStyle(color: n.textSecondary),
                ),
              ),
              const SizedBox(height: 20),
              Column(
                children: [
                  if (transaction.fromVault != null) ...[
                    _DetailCard(icon: Icons.arrow_upward_rounded, color: AppColors.expense, label: 'Từ túi', value: transaction.fromVault!.name, neutrals: n),
                    const SizedBox(height: 10),
                  ],
                  if (transaction.toVault != null) ...[
                    _DetailCard(icon: Icons.arrow_downward_rounded, color: AppColors.income, label: 'Đến túi', value: transaction.toVault!.name, neutrals: n),
                    const SizedBox(height: 10),
                  ],
                  if (transaction.category != null) ...[
                    _DetailCard(
                      icon: Icons.category_outlined,
                      color: AppColors.forKey(transaction.category!.name),
                      label: 'Danh mục',
                      value: transaction.category!.name,
                      neutrals: n,
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (transaction.costAmount != null) ...[
                    _DetailCard(icon: Icons.point_of_sale_outlined, color: AppColors.transfer, label: 'Giá vốn hàng bán', value: formatVND(transaction.costAmount!), neutrals: n),
                    const SizedBox(height: 10),
                  ],
                  if (transaction.profit != null) ...[
                    _DetailCard(
                      icon: transaction.profit! >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      color: transaction.profit! >= 0 ? AppColors.income : AppColors.error,
                      label: 'Lợi nhuận',
                      value: formatVND(transaction.profit!),
                      neutrals: n,
                      valueColor: transaction.profit! >= 0 ? AppColors.income : AppColors.error,
                    ),
                    const SizedBox(height: 10),
                  ],
                  if ((transaction.note ?? '').isNotEmpty) ...[
                    _DetailCard(icon: Icons.sticky_note_2_outlined, color: AppColors.primary, label: 'Ghi chú', value: transaction.note!, neutrals: n),
                    const SizedBox(height: 10),
                  ],
                  _DetailCard(icon: Icons.schedule_outlined, color: AppColors.secondary, label: 'Thời gian', value: dateFormat.format(transaction.createdAt), neutrals: n),
                  if (transaction.createdBy != null) ...[
                    const SizedBox(height: 10),
                    _DetailCard(
                      icon: Icons.person_outline_rounded,
                      color: AppColors.forKey(transaction.createdBy!.name),
                      label: 'Người tạo',
                      value: transaction.createdBy!.name,
                      neutrals: n,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              if (!transaction.isVoided && !transaction.pending && ref.watch(canEditTransactionsProvider)) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Sửa giao dịch'),
                    onPressed: () async {
                      final updated = await showEditTransactionSheet(sheetContext, transaction);
                      if (updated != null) {
                        ref.read(transactionListProvider.notifier).loadFirstPage();
                        if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                      }
                    },
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Hủy giao dịch'),
                    onPressed: () async {
                      final reason = await _promptVoidReason(sheetContext);
                      if (reason == null) return; // user cancelled
                      try {
                        final updated = await ref
                            .read(transactionRepositoryProvider)
                            .voidTransaction(transaction.id, reason: reason.isEmpty ? null : reason);
                        ref.read(transactionListProvider.notifier).replaceTransaction(updated);
                        if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                      } catch (e) {
                        final message = e is ApiException ? e.message : 'Không thể hủy giao dịch';
                        if (sheetContext.mounted) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(content: Text(message)));
                        }
                      }
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

/// Simple confirm dialog with an optional reason field, shown before voiding
/// a transaction — the reason (if any) is recorded on the audit log entry
/// only. Returns the entered text (possibly empty) to confirm, or `null` if
/// the user cancelled.
Future<String?> _promptVoidReason(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Hủy giao dịch?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Giao dịch sẽ được đánh dấu đã hủy, không bị xóa khỏi lịch sử.'),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Lý do (không bắt buộc)', border: OutlineInputBorder()),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Đóng')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: const Text('Hủy giao dịch', style: TextStyle(color: AppColors.error)),
        ),
      ],
    ),
  );
}

/// A single labeled fact in the transaction detail sheet, given its own
/// color-coded card (icon + tint matching the kind of info it holds — vault
/// vs category vs note vs creator, ...) instead of a bare text row, so the
/// sheet reads at a glance instead of as a wall of label/value pairs.
class _DetailCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final ScreenNeutrals neutrals;
  final Color? valueColor;

  const _DetailCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.neutrals,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: neutrals.cardDecoration(radius: 12, accent: color),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 18, backgroundColor: color.withValues(alpha: 0.14), child: Icon(icon, size: 18, color: color)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: neutrals.textSecondary)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor ?? neutrals.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
