import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/theme/screen_neutrals.dart';
import '../../../core/theme/section_accents.dart';
import '../../../core/theme/visual_style_provider.dart';
import 'auth_hero_header.dart';
import 'auth_notifier.dart';
import 'social_sign_in_buttons.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    final emailRegex = RegExp(r'^[\w\.\-\+]+@[\w\-]+\.[\w\-\.]+$');
    if (v.isEmpty || !emailRegex.hasMatch(v)) return 'Email không hợp lệ';
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').isEmpty) return 'Vui lòng nhập mật khẩu';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await ref.read(authNotifierProvider.notifier).login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      // Router redirect (app.dart) takes over once auth state flips.
    } catch (e) {
      final message = e is ApiException ? e.message : 'Đăng nhập thất bại. Vui lòng thử lại.';
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
            const AuthHeroHeader(
              title: 'Sổ Thu Chi',
              subtitle: 'Quản lý dòng tiền cho shop và gia đình,\nrõ ràng và đơn giản',
            ),
            AuthFormSheet(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Đăng nhập', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: n.textPrimary)),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      enableSuggestions: false,
                      style: TextStyle(color: n.textPrimary),
                      decoration: authFieldDecoration(label: 'Email', icon: Icons.mail_outline, neutrals: n, accent: accent),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      style: TextStyle(color: n.textPrimary),
                      decoration: authFieldDecoration(
                        label: 'Mật khẩu',
                        icon: Icons.lock_outline,
                        neutrals: n,
                        accent: accent,
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: _validatePassword,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.push('/forgot-password'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          minimumSize: const Size(0, 32),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                        child: Text('Quên mật khẩu?', style: TextStyle(color: accent, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    AuthPrimaryButton(label: 'Đăng nhập', loading: _isSubmitting, onPressed: _submit),
                    const SizedBox(height: 14),
                    Center(
                      child: TextButton(
                        onPressed: () => context.push('/register'),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(fontSize: 13.5, color: n.textSecondary),
                            children: [
                              const TextSpan(text: 'Chưa có tài khoản? '),
                              TextSpan(text: 'Đăng ký ngay', style: TextStyle(color: accent, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
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
