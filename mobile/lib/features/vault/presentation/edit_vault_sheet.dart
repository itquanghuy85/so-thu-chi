import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/api_exception.dart';
import '../../../shared/widgets/sheet_drag_handle.dart';
import '../data/vault_repository.dart';
import '../domain/vault.dart';
import 'vault_list_screen.dart' show vaultTypeIcon;

/// Bottom sheet to rename / change the type of an existing [vault]
/// (Mục 12.7 edit). Amounts are intentionally not editable here — the
/// balance only ever changes via Kiểm kê / giao dịch. Returns `true` on a
/// successful save so callers can refresh.
Future<bool?> showEditVaultSheet(BuildContext context, Vault vault) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => EditVaultSheet(vault: vault),
  );
}

class EditVaultSheet extends ConsumerStatefulWidget {
  final Vault vault;

  const EditVaultSheet({super.key, required this.vault});

  @override
  ConsumerState<EditVaultSheet> createState() => _EditVaultSheetState();
}

class _EditVaultSheetState extends ConsumerState<EditVaultSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController = TextEditingController(text: widget.vault.name);
  late VaultType _type = widget.vault.type;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty || v.length > 100) return 'Tên từ 1 đến 100 ký tự';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(vaultRepositoryProvider).updateVault(
            vaultId: widget.vault.id,
            name: _nameController.text.trim(),
            type: _type,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      final message = e is ApiException ? e.message : 'Không thể sửa túi tiền';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: SheetDragHandle()),
            const Text('Sửa túi tiền', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Tên túi tiền', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              validator: _validateName,
            ),
            const SizedBox(height: 16),
            const Text('Loại túi', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: VaultType.values.map((t) {
                final selected = t == _type;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: t == VaultType.values.last ? 0 : 8),
                    child: InkWell(
                      onTap: () => setState(() => _type = t),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: selected ? AppColors.primary : AppColors.divider, width: selected ? 2 : 1),
                          borderRadius: BorderRadius.circular(12),
                          color: selected ? AppColors.primary.withValues(alpha: 0.06) : null,
                        ),
                        child: Column(
                          children: [
                            Icon(vaultTypeIcon(t), color: selected ? AppColors.primary : AppColors.textSecondary),
                            const SizedBox(height: 6),
                            Text(
                              vaultTypeLabel(t),
                              style: TextStyle(fontSize: 12, color: selected ? AppColors.primary : AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isSaving ? null : _submit,
              child: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Lưu thay đổi'),
            ),
          ],
        ),
      ),
    );
  }
}