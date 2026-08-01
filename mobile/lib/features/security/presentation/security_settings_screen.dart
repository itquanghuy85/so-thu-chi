import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../data/app_lock_service.dart';
import 'app_lock_notifier.dart';

/// Cài PIN / Vân tay (Mục 14, from Profile/Settings). Sets/changes/removes
/// the local PIN and toggles biometric unlock (only shown when the device
/// actually has usable biometric hardware enrolled).
class SecuritySettingsScreen extends ConsumerStatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  ConsumerState<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends ConsumerState<SecuritySettingsScreen> {
  bool _hasPin = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = ref.read(appLockServiceProvider);
    final hasPin = await service.hasPin();
    final available = await service.isBiometricAvailable();
    final enabled = await service.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _hasPin = hasPin;
        _biometricAvailable = available;
        _biometricEnabled = enabled;
        _loading = false;
      });
    }
  }

  Future<void> _setNewPin() async {
    final firstPin = await _promptPin('Đặt mã PIN', 'Nhập mã PIN gồm 6 số');
    if (firstPin == null || !mounted) return;
    final confirmPin = await _promptPin('Xác nhận mã PIN', 'Nhập lại mã PIN vừa tạo');
    if (confirmPin == null) return;
    if (firstPin != confirmPin) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hai mã PIN không khớp. Vui lòng thử lại.')));
      return;
    }
    await ref.read(appLockServiceProvider).setPin(firstPin);
    await ref.read(appLockNotifierProvider.notifier).refreshPinConfigured();
    await _load();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã đặt mã PIN')));
  }

  Future<void> _changePin() async {
    final current = await _promptPin('Xác nhận mã PIN hiện tại', 'Nhập mã PIN hiện tại');
    if (current == null || !mounted) return;
    final ok = await ref.read(appLockServiceProvider).verifyPin(current);
    if (!ok) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mã PIN không đúng')));
      return;
    }
    await _setNewPin();
  }

  Future<void> _removePin() async {
    final current = await _promptPin('Xác nhận mã PIN hiện tại', 'Nhập mã PIN để tắt khoá app');
    if (current == null || !mounted) return;
    final ok = await ref.read(appLockServiceProvider).verifyPin(current);
    if (!ok) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mã PIN không đúng')));
      return;
    }
    await ref.read(appLockServiceProvider).clearPin();
    await ref.read(appLockNotifierProvider.notifier).refreshPinConfigured();
    await _load();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã tắt khoá bằng mã PIN')));
  }

  Future<String?> _promptPin(String title, String subtitle) {
    return showDialog<String>(
      context: context,
      builder: (_) => _PinPromptDialog(title: title, subtitle: subtitle),
    );
  }

  Future<void> _toggleBiometric(bool value) async {
    await ref.read(appLockServiceProvider).setBiometricEnabled(value);
    setState(() => _biometricEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Bảo mật')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(backgroundColor: AppColors.primary.withValues(alpha: 0.12), child: const Icon(Icons.pin_outlined, color: AppColors.primary)),
                        title: const Text('Khoá bằng mã PIN', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(_hasPin ? 'Đang bật' : 'Chưa thiết lập'),
                        trailing: Switch(
                          value: _hasPin,
                          onChanged: (value) => value ? _setNewPin() : _removePin(),
                        ),
                      ),
                      if (_hasPin) ...[
                        const Divider(height: 1),
                        ListTile(
                          leading: const SizedBox(width: 40),
                          title: const Text('Đổi mã PIN'),
                          trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                          onTap: _changePin,
                        ),
                        if (_biometricAvailable) ...[
                          const Divider(height: 1),
                          ListTile(
                            leading: const SizedBox(width: 40),
                            title: const Text('Mở khoá bằng vân tay / khuôn mặt'),
                            trailing: Switch(value: _biometricEnabled, onChanged: _toggleBiometric),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Khi bật, ứng dụng sẽ yêu cầu xác thực lại nếu bạn rời ứng dụng quá 5 phút.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
    );
  }
}

class _PinPromptDialog extends StatefulWidget {
  final String title;
  final String subtitle;

  const _PinPromptDialog({required this.title, required this.subtitle});

  @override
  State<_PinPromptDialog> createState() => _PinPromptDialogState();
}

class _PinPromptDialogState extends State<_PinPromptDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.length == 6) Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.subtitle, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, letterSpacing: 8),
            decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), counterText: ''),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Huỷ')),
        FilledButton(
          onPressed: _controller.text.length == 6 ? _submit : null,
          child: const Text('Xác nhận'),
        ),
      ],
    );
  }
}
