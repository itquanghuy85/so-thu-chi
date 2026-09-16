import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/theme/screen_neutrals.dart';
import '../../../core/theme/section_accents.dart';
import '../../../core/theme/visual_style_provider.dart';
import '../data/auth_repository.dart';
import 'auth_hero_header.dart';

enum _Step { email, otp }

/// "Quên mật khẩu" (two steps, spec Mục — `forgot-password` +
/// `reset-password`): 1) enter the account email to receive a 6-digit OTP,
/// 2) enter the OTP and a new password. Returns `true` if the password was
/// reset, so the caller (login screen) can pop and give feedback.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  _Step _step = _Step.email;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    final emailRegex = RegExp(r'^[\w\.\-\+]+@[\w\-]+\.[\w\-\.]+$');
    if (v.isEmpty || !emailRegex.hasMatch(v)) return 'Email không hợp lệ';
    return null;
  }

  String? _validateOtp(String? value) {
    final v = value?.trim() ?? '';
    if (v.length != 6) return 'Mã OTP gồm 6 chữ số';
    return null;
  }

  String? _validateNewPassword(String? value) {
    final v = value ?? '';
    final strongEnough = v.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(v) &&
        RegExp(r'\d').hasMatch(v) &&
        RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]/\\;]').hasMatch(v);
    if (!strongEnough) return 'Mật khẩu ít nhất 8 ký tự, bao gồm chữ hoa, số và ký hiệu';
    return null;
  }

  String? _validateConfirm(String? value) {
    if (value != _passwordController.text) return 'Mật khẩu không khớp';
    return null;
  }

  String _friendlyApiMessage(ApiException e) {
    // The password-reset endpoints are specified but not deployed yet, so a
    // bare 404 from the server should read as "coming soon" rather than a
    // raw "Cannot POST ..." network error.
    if (e.code == 'NOT_FOUND' || e.code == 'UNKNOWN_ERROR') {
      return 'Tính năng đặt lại mật khẩu chưa khả dụng ngay bây giờ. Vui lòng thử lại sau.';
    }
    switch (e.code) {
      case 'INVALID_OTP':
        return 'Mã OTP không đúng. Vui lòng kiểm tra lại.';
      case 'OTP_EXPIRED':
        return 'Mã OTP đã hết hạn. Hãy gửi lại mã mới.';
      default:
        return e.message;
    }
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await ref.read(authRepositoryProvider).forgotPassword(_emailController.text.trim());
      if (mounted) setState(() => _step = _Step.otp);
    } catch (e) {
      final message = e is ApiException ? _friendlyApiMessage(e) : 'Không thể gửi mã xác thực. Vui lòng thử lại.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await ref.read(authRepositoryProvider).resetPassword(
            email: _emailController.text.trim(),
            otp: _otpController.text.trim(),
            newPassword: _passwordController.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mật khẩu đã được đặt lại. Vui lòng đăng nhập bằng mật khẩu mới.')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      final message = e is ApiException ? _friendlyApiMessage(e) : 'Không thể đặt lại mật khẩu. Vui lòng thử lại.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = ref.watch(visualStyleProvider);
    final n = neutralsFor(style);
    final accent = sectionAccent(AppSection.dashboard, style);

    return Scaffold(
      backgroundColor: n.surface,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthHeroHeader(
              title: 'Quên mật khẩu',
              subtitle: _step == _Step.email
                  ? 'Nhập email của tài khoản để nhận\nmã xác thực (OTP)'
                  : 'Nhập mã OTP và tạo mật khẩu mới',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            AuthFormSheet(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _step == _Step.email ? 'Bước 1 — Nhận mã xác thực' : 'Bước 2 — Đặt mật khẩu mới',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: n.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _step == _Step.email
                          ? 'Chúng tôi sẽ gửi mã OTP 6 số vào email của bạn. Mã có hiệu lực trong 15 phút.'
                          : 'Mã OTP đã gửi tới ${_emailController.text.trim()}.',
                      style: TextStyle(fontSize: 13, color: n.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    if (_step == _Step.email) ...[
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        enableSuggestions: false,
                        style: TextStyle(color: n.textPrimary),
                        decoration: authFieldDecoration(label: 'Email', icon: Icons.mail_outline, neutrals: n, accent: accent),
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 24),
                      AuthPrimaryButton(label: 'Gửi mã xác thực', loading: _isSubmitting, onPressed: _sendOtp),
                    ] else ...[
                      TextFormField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        maxLength: 6,
                        style: TextStyle(color: n.textPrimary, fontSize: 20, letterSpacing: 8),
                        decoration: authFieldDecoration(label: 'Mã OTP', icon: Icons.pin_outlined, neutrals: n, accent: accent)
                            .copyWith(counterText: ''),
                        validator: _validateOtp,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        autocorrect: false,
                        enableSuggestions: false,
                        style: TextStyle(color: n.textPrimary),
                        decoration: authFieldDecoration(
                          label: 'Mật khẩu mới',
                          icon: Icons.lock_outline,
                          neutrals: n,
                          accent: accent,
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: _validateNewPassword,
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          'Ít nhất 8 ký tự, gồm chữ hoa, số và ký hiệu',
                          style: TextStyle(fontSize: 11.5, color: n.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmController,
                        obscureText: _obscurePassword,
                        autocorrect: false,
                        enableSuggestions: false,
                        style: TextStyle(color: n.textPrimary),
                        decoration: authFieldDecoration(label: 'Xác nhận mật khẩu', icon: Icons.lock_outline, neutrals: n, accent: accent),
                        validator: _validateConfirm,
                      ),
                      const SizedBox(height: 24),
                      AuthPrimaryButton(label: 'Đặt lại mật khẩu', loading: _isSubmitting, onPressed: _resetPassword),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: _isSubmitting ? null : _sendOtp,
                          child: const Text('Gửi lại mã OTP'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}