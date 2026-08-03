import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/screen_neutrals.dart';
import '../../../core/theme/section_accents.dart';
import '../../../core/theme/visual_style_provider.dart';
import '../../../shared/widgets/initials_avatar.dart';
import '../../../shared/widgets/section_app_bar.dart';
import '../../auth/presentation/auth_notifier.dart';
import 'delete_account_flow.dart';

/// "Trang cá nhân" — reachable by tapping the Dashboard's greeting/avatar
/// or the user card at the top of Cài đặt. Ảnh đại diện/tên/SĐT edit here;
/// email stays read-only (it's the login identity); mật khẩu has its own
/// dialog since it needs the current password re-checked, not a plain
/// field save.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  bool _saving = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authNotifierProvider).user;
    _nameController = TextEditingController(text: user?.fullName ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 85);
    if (picked == null || !mounted) return;
    setState(() => _uploadingAvatar = true);
    try {
      await ref.read(authNotifierProvider.notifier).uploadAvatar(File(picked.path));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật ảnh đại diện')));
    } catch (e) {
      final message = e is ApiException ? e.message : 'Không thể tải ảnh lên';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tên không được để trống')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(authNotifierProvider.notifier).updateProfile(
            fullName: name,
            phone: _phoneController.text.trim(),
          );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu thông tin cá nhân')));
    } catch (e) {
      final message = e is ApiException ? e.message : 'Không thể lưu thông tin';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã đổi mật khẩu')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = ref.watch(visualStyleProvider);
    final n = neutralsFor(style);
    final accent = sectionAccent(AppSection.settings, style);
    final user = ref.watch(authNotifierProvider).user;

    return Scaffold(
      backgroundColor: n.tint(accent),
      appBar: SectionAppBar(title: 'Trang cá nhân', style: style),
      body: user == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Stack(
                    children: [
                      InitialsAvatar(name: user.fullName, radius: 48, imageUrl: user.avatarUrl),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                          child: Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: accent, shape: BoxShape.circle, border: Border.all(color: n.surface, width: 2)),
                            child: _uploadingAvatar
                                ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text('Chạm vào biểu tượng máy ảnh để đổi ảnh', style: TextStyle(fontSize: 11.5, color: n.textSecondary)),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: n.cardDecoration(radius: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Thông tin cá nhân', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: n.textPrimary)),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _nameController,
                        style: TextStyle(color: n.textPrimary),
                        decoration: const InputDecoration(labelText: 'Họ tên', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(color: n.textPrimary),
                        decoration: const InputDecoration(labelText: 'Số điện thoại', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        enabled: false,
                        controller: TextEditingController(text: user.email),
                        style: TextStyle(color: n.textSecondary),
                        decoration: const InputDecoration(labelText: 'Email (không thể đổi)', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: accent),
                          onPressed: _saving ? null : _saveProfile,
                          child: _saving
                              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Lưu thay đổi'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: n.cardDecoration(radius: 14),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: accent.withValues(alpha: 0.12), child: Icon(Icons.lock_outline, color: accent)),
                    title: Text('Đổi mật khẩu', style: TextStyle(fontWeight: FontWeight.w600, color: n.textPrimary)),
                    trailing: Icon(Icons.chevron_right, color: n.textSecondary),
                    onTap: _changePassword,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: n.cardDecoration(radius: 14),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: AppColors.error.withValues(alpha: 0.12), child: const Icon(Icons.delete_forever_outlined, color: AppColors.error)),
                    title: const Text('Xoá tài khoản', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.error)),
                    subtitle: Text('Xoá vĩnh viễn tài khoản và toàn bộ dữ liệu', style: TextStyle(color: n.textSecondary)),
                    onTap: () => confirmAndDeleteAccount(context, ref),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_currentController.text.isEmpty || _newController.text.isEmpty) {
      setState(() => _error = 'Vui lòng nhập đầy đủ');
      return;
    }
    if (_newController.text.length < 8) {
      setState(() => _error = 'Mật khẩu mới phải có ít nhất 8 ký tự');
      return;
    }
    if (_newController.text != _confirmController.text) {
      setState(() => _error = 'Mật khẩu mới nhập lại không khớp');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authNotifierProvider.notifier).changePassword(
            currentPassword: _currentController.text,
            newPassword: _newController.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      final message = e is ApiException ? e.message : 'Không thể đổi mật khẩu';
      setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Đổi mật khẩu'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _currentController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Mật khẩu hiện tại'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _newController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Mật khẩu mới'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _confirmController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Nhập lại mật khẩu mới'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12.5)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Huỷ')),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Đổi mật khẩu'),
        ),
      ],
    );
  }
}
