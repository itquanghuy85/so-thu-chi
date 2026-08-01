import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
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
          children: [
            const Expanded(child: Divider(color: AppColors.divider)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text('hoặc', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ),
            const Expanded(child: Divider(color: AppColors.divider)),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 50,
          child: OutlinedButton(
            onPressed: _busy ? null : () => _handle(_service.signInWithGoogle, 'google'),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              side: const BorderSide(color: AppColors.divider),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 20, height: 20, child: CustomPaint(painter: _GoogleGPainter())),
                const SizedBox(width: 12),
                Text('Đăng nhập với Google', style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.87), fontWeight: FontWeight.w600, fontSize: 14.5)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 50,
          child: FilledButton(
            onPressed: _busy ? null : () => _handle(_service.signInWithApple, 'apple'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.apple, color: Colors.white, size: 22),
                SizedBox(width: 8),
                Text('Đăng nhập với Apple', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14.5)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Draws an approximation of the Google "G" mark (4-color ring + the
/// crossbar) — `Icons.g_mobiledata` (the previous icon here) is Android's
/// mobile-data-network glyph, not a Google logo, and reads as a mistake up
/// close. No brand asset is bundled with the app, so this is painted
/// directly rather than shipping an image.
class _GoogleGPainter extends CustomPainter {
  const _GoogleGPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = size.width * 0.24;
    final radius = size.width / 2 - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    void arc(double startDeg, double sweepDeg, Color color) {
      ringPaint.color = color;
      canvas.drawArc(rect, startDeg * math.pi / 180, sweepDeg * math.pi / 180, false, ringPaint);
    }

    arc(-84, 78, const Color(0xFF4285F4));
    arc(-2, 78, const Color(0xFF34A853));
    arc(80, 78, const Color(0xFFFBBC05));
    arc(162, 78, const Color(0xFFEA4335));

    final barPaint = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(center.dx - strokeWidth * 0.1, center.dy - strokeWidth / 2, radius + strokeWidth * 0.1, strokeWidth),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
