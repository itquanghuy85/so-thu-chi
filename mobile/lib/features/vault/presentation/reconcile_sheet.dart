import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/amount_text_field.dart';
import '../../../shared/widgets/sheet_drag_handle.dart';
import '../data/vault_repository.dart';
import '../domain/vault.dart';
import 'vault_list_screen.dart';

/// "Kiểm kê" (reconcile) flow (Mục 12.9): pick a vault, then enter its
/// actual counted balance. Returns `true` if a reconciliation was saved.
Future<bool?> showReconcileFlow(BuildContext context, WidgetRef ref) async {
  final vaults = await ref.read(vaultListProvider.future);
  if (!context.mounted) return null;
  if (vaults.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chưa có túi tiền nào để kiểm kê.')),
    );
    return null;
  }
  final vault = await showModalBottomSheet<Vault>(
    context: context,
    builder: (sheetContext) => _VaultPickerSheet(vaults: vaults),
  );
  if (vault == null || !context.mounted) return null;
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ReconcileForm(vault: vault),
  );
}

class _VaultPickerSheet extends StatelessWidget {
  final List<Vault> vaults;

  const _VaultPickerSheet({required this.vaults});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Chọn túi để kiểm kê', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          ...vaults.map((v) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Icon(vaultTypeIcon(v.type), color: AppColors.primary),
                ),
                title: Text(v.name),
                subtitle: Text('Số dư hệ thống: ${formatVND(v.currentBalance)}'),
                onTap: () => Navigator.of(context).pop(v),
              )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ReconcileForm extends ConsumerStatefulWidget {
  final Vault vault;

  const _ReconcileForm({required this.vault});

  @override
  ConsumerState<_ReconcileForm> createState() => _ReconcileFormState();
}

class _ReconcileFormState extends ConsumerState<_ReconcileForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  int get _difference => parseCurrencyInput(_amountController.text) - widget.vault.currentBalance.round();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(vaultRepositoryProvider).reconcile(
            vaultId: widget.vault.id,
            actualBalance: parseCurrencyInput(_amountController.text),
            reason: _reasonController.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      final message = e is ApiException ? e.message : 'Không thể lưu kiểm kê';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: SheetDragHandle()),
              const SizedBox(height: 4),
              Text('Kiểm kê ${widget.vault.name}', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('Số dư hệ thống: ${formatVND(widget.vault.currentBalance)}',
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              AmountTextField(
                controller: _amountController,
                label: 'Số tiền thực tế',
                allowZero: true,
                onChanged: (_) => setState(() {}),
              ),
              if (_amountController.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _difference == 0
                      ? 'Khớp với sổ sách'
                      : _difference > 0
                          ? 'Thừa ${formatVND(_difference)}'
                          : 'Thiếu ${formatVND(-_difference)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _difference == 0 ? AppColors.income : AppColors.error,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _reasonController,
                decoration: InputDecoration(labelText: 'Lý do (tuỳ chọn)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _submit,
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Xác nhận kiểm kê'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
