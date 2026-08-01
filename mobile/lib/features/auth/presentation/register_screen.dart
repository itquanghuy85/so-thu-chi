import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/api_exception.dart';
import 'auth_hero_header.dart';
import 'auth_notifier.dart';
import 'social_sign_in_buttons.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateFullName(String? value) {
    final v = value?.trim() ?? '';
    if (v.length < 2 || v.length > 100) return 'Họ tên từ 2 đến 100 ký tự';
    return null;
  }

  String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    final emailRegex = RegExp(r'^[\w\.\-\+]+@[\w\-]+\.[\w\-\.]+$');
    if (v.isEmpty || !emailRegex.hasMatch(v)) return 'Email không hợp lệ';
    return null;
  }

  String? _validatePassword(String? value) {
    final v = value ?? '';
    final strongEnough = v.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(v) &&
        RegExp(r'\d').hasMatch(v) &&
        RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]/\\;]').hasMatch(v);
    if (!strongEnough) {
      return 'Mật khẩu ít nhất 8 ký tự, bao gồm chữ hoa, số và ký hiệu';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value != _passwordController.text) return 'Mật khẩu không khớp';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await ref.read(authNotifierProvider.notifier).register(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            fullName: _fullNameController.text.trim(),
          );
      // Router redirect (app.dart) takes over once auth state flips.
    } catch (e) {
      final message = e is ApiException ? e.message : 'Đăng ký thất bại. Vui lòng thử lại.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthHeroHeader(
              title: 'Tạo tài khoản',
              subtitle: 'Chỉ mất chưa đầy một phút để bắt đầu\nquản lý dòng tiền của bạn',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            AuthFormSheet(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _fullNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: authFieldDecoration(label: 'Họ tên', icon: Icons.person_outline),
                      validator: _validateFullName,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: authFieldDecoration(label: 'Email', icon: Icons.mail_outline),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: authFieldDecoration(
                        label: 'Mật khẩu',
                        icon: Icons.lock_outline,
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: _validatePassword,
                    ),
                    const SizedBox(height: 6),
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Text(
                        'Ít nhất 8 ký tự, gồm chữ hoa, số và ký hiệu',
                        style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscurePassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: authFieldDecoration(label: 'Xác nhận mật khẩu', icon: Icons.lock_outline),
                      validator: _validateConfirmPassword,
                    ),
                    const SizedBox(height: 24),
                    AuthPrimaryButton(label: 'Tạo tài khoản', loading: _isSubmitting, onPressed: _submit),
                    const SizedBox(height: 18),
                    const SocialSignInButtons(),
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
