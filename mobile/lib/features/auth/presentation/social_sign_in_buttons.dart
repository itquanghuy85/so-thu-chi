import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../data/social_auth_service.dart';
import 'auth_notifier.dart';

/// "Đăng nhập với Google" / "Đăng nhập với Apple" buttons shared by the
/// Login and Register screens — a social sign-in doubles as registration
/// automatically (the backend finds-or-creates the user by email).
class SocialSignInButtons extends ConsumerStatefulWidget {
  const SocialSignInButtons({super.key});

  @override
  ConsumerState<SocialSignInButtons> createState() => _SocialSignInButtonsState();
}

class _SocialSignInButtonsState extends ConsumerState<SocialSignInButtons> {
  final _service = SocialAuthService();
  bool _busy = false;

  Future<void> _handle(Future<String> Function() getIdToken, String provider) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final idToken = await getIdToken();
      await ref.read(authNotifierProvider.notifier).socialSignIn(idToken: idToken, provider: provider);
      // Router redirect (app.dart) takes over once auth state flips.
    } on SocialSignInCancelled {
      // User backed out of the account picker — nothing to show.
    } catch (e) {
      final message = e is ApiException
          ? e.message
          : provider == 'apple'
              ? 'Đăng nhập Apple chưa khả dụng trên thiết bị này.'
              : 'Đăng nhập Google thất bại. Vui lòng thử lại.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: const [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('hoặc', style: TextStyle(color: Colors.grey)),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _handle(_service.signInWithGoogle, 'google'),
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
          icon: const Icon(Icons.g_mobiledata, size: 28),
          label: const Text('Đăng nhập với Google'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _handle(_service.signInWithApple, 'apple'),
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
          icon: const Icon(Icons.apple, size: 22),
          label: const Text('Đăng nhập với Apple'),
        ),
      ],
    );
  }
}
