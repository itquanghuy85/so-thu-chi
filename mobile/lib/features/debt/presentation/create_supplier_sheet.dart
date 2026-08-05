import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../shared/providers/current_workspace_provider.dart';
import '../../../shared/widgets/sheet_drag_handle.dart';
import '../data/supplier_repository.dart';
import '../domain/customer.dart';

Future<Customer?> showCreateSupplierSheet(BuildContext context) {
  return showModalBottomSheet<Customer>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const CreateSupplierSheet(),
  );
}

class CreateSupplierSheet extends ConsumerStatefulWidget {
  const CreateSupplierSheet({super.key});

  @override
  ConsumerState<CreateSupplierSheet> createState() => _CreateSupplierSheetState();
}

class _CreateSupplierSheetState extends ConsumerState<CreateSupplierSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty || v.length > 100) return 'Tên từ 1 đến 100 ký tự';
    return null;
  }

  String? _validatePhone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (!RegExp(r'^0\d{8,10}$').hasMatch(v)) return 'Số điện thoại không hợp lệ';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final workspaceId = ref.read(currentWorkspaceIdProvider);
      final supplier = await ref.read(supplierRepositoryProvider).createSupplier(
            workspaceId: workspaceId,
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
          );
      ref.invalidate(supplierListProvider);
      if (mounted) Navigator.of(context).pop(supplier);
    } catch (e) {
      final message = e is ApiException ? e.message : 'Không thể thêm nhà cung cấp';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetDragHandle(),
            const SizedBox(height: 12),
            const Text('Thêm nhà cung cấp', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Tên nhà cung cấp *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              textCapitalization: TextCapitalization.words,
              validator: _validateName,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Số điện thoại (không bắt buộc)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.phone,
              validator: _validatePhone,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSaving ? null : _submit,
                child: _isSaving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Lưu'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
