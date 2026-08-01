import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../shared/providers/current_workspace_provider.dart';
import '../../../shared/widgets/sheet_drag_handle.dart';
import '../data/customer_repository.dart';
import '../domain/customer.dart';

/// Bottom sheet to add a customer (Mục 12.10). Returns the created
/// [Customer] on success so callers (e.g. the debt tab in the create
/// transaction sheet) can immediately select it.
Future<Customer?> showCreateCustomerSheet(BuildContext context) {
  return showModalBottomSheet<Customer>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const CreateCustomerSheet(),
  );
}

class CreateCustomerSheet extends ConsumerStatefulWidget {
  const CreateCustomerSheet({super.key});

  @override
  ConsumerState<CreateCustomerSheet> createState() => _CreateCustomerSheetState();
}

class _CreateCustomerSheetState extends ConsumerState<CreateCustomerSheet> {
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
    if (v.isEmpty) return null; // optional
    if (!RegExp(r'^0\d{8,10}$').hasMatch(v)) return 'Số điện thoại không hợp lệ';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final workspaceId = ref.read(currentWorkspaceIdProvider);
      final customer = await ref.read(customerRepositoryProvider).createCustomer(
            workspaceId: workspaceId,
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
          );
      ref.invalidate(customerListProvider);
      if (mounted) Navigator.of(context).pop(customer);
    } catch (e) {
      final message = e is ApiException ? e.message : 'Không thể thêm khách hàng';
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
            const Text('Thêm khách hàng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Tên khách hàng', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              validator: _validateName,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration:
                  InputDecoration(labelText: 'Số điện thoại (tuỳ chọn)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              validator: _validatePhone,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isSaving ? null : _submit,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}
