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
        accent: accent,
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
                  _TypeChip(label: 'Thu', selected: state.filter.type == TransactionType.income, color: AppColors.income, neutrals: n, onTap: () => notifier.setFilter(state.filter.copyWith(type: TransactionType.income))),
                  const SizedBox(width: 8),
                  _TypeChip(label: 'Chi', selected: state.filter.type == TransactionType.expense, color: AppColors.expense, neutrals: n, onTap: () => notifier.setFilter(state.filter.copyWith(type: TransactionType.expense))),
                  const SizedBox(width: 8),
                  _TypeChip(label: 'Chuyển', selected: state.filter.type == TransactionType.transfer, color: AppColors.transfer, neutrals: n, onTap: () => notifier.setFilter(state.filter.copyWith(type: TransactionType.transfer))),
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
      await excelExportService.exportTransactions(transactions: all, periodLabel: filter.period.label);
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
    final n = neutralsFor(ref.watch(visualStyleProvider));
    final color = transactionColor(transaction.type);
    final timeFormat = DateFormat('HH:mm dd/MM', 'vi_VN');
    final isVoided = transaction.isVoided;

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
                    color: AppColors.transfer.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Chờ đồng bộ', style: TextStyle(fontSize: 10, color: AppColors.transfer, fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
          subtitle: Text(
            [transactionDescription(transaction), timeFormat.format(transaction.createdAt)]
                .where((s) => s.isNotEmpty)
                .join(' • '),
            style: TextStyle(color: n.textSecondary),
          ),
          trailing: Text(
            '${transactionAmountSign(transaction.type)}${formatVND(transaction.amount)}',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet showing transaction detail (Mục 12.5.1) with a "Hủy giao
/// dịch" action when the transaction is still active.
void showTransactionDetailSheet(BuildContext context, WidgetRef ref, Transaction transaction) {
  final color = transactionColor(transaction.type);
  final n = neutralsFor(ref.read(visualStyleProvider));
  showModalBottomSheet(
    context: context,
    backgroundColor: n.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) {
      final dateFormat = DateFormat('HH:mm, dd/MM/yyyy', 'vi_VN');
      return SafeArea(
        child: Padding(
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
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: n.background, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  children: [
                    if (transaction.fromVault != null) _DetailRow(label: 'Từ túi', value: transaction.fromVault!.name, neutrals: n),
                    if (transaction.toVault != null) _DetailRow(label: 'Đến túi', value: transaction.toVault!.name, neutrals: n),
                    if (transaction.category != null) _DetailRow(label: 'Danh mục', value: transaction.category!.name, neutrals: n),
                    if (transaction.costAmount != null) _DetailRow(label: 'Giá vốn hàng bán', value: formatVND(transaction.costAmount!), neutrals: n),
                    if (transaction.profit != null)
                      _DetailRow(
                        label: 'Lợi nhuận',
                        value: formatVND(transaction.profit!),
                        neutrals: n,
                        valueColor: transaction.profit! >= 0 ? AppColors.income : AppColors.error,
                      ),
                    if ((transaction.note ?? '').isNotEmpty) _DetailRow(label: 'Ghi chú', value: transaction.note!, neutrals: n),
                    _DetailRow(label: 'Thời gian', value: dateFormat.format(transaction.createdAt), neutrals: n),
                  ],
                ),
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

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final ScreenNeutrals neutrals;
  final Color? valueColor;

  const _DetailRow({required this.label, required this.value, required this.neutrals, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: TextStyle(color: neutrals.textSecondary))),
          Expanded(child: Text(value, style: TextStyle(fontWeight: FontWeight.w500, color: valueColor ?? neutrals.textPrimary))),
        ],
      ),
    );
  }
}
