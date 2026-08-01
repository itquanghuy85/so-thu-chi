import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/game_colors.dart';

enum LeonMood { happy, excited, sleepy, proud }

/// Leon — the hand-painted (via [CustomPainter], no external art assets)
/// lion mascot for the "Game Leon" visual style (Mục 16.2). Procedurally
/// drawn rather than an imported image so it scales crisply at any size
/// and needs no illustration pipeline. Idles with a gentle breathing
/// scale-pulse and an occasional blink so it reads as alive, not static.
class LeonMascot extends StatefulWidget {
  final double size;
  final LeonMood mood;
  final bool crowned;

  const LeonMascot({super.key, this.size = 120, this.mood = LeonMood.happy, this.crowned = false});

  @override
  State<LeonMascot> createState() => _LeonMascotState();
}

class _LeonMascotState extends State<LeonMascot> with TickerProviderStateMixin {
  late final AnimationController _breathController =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat(reverse: true);
  late final AnimationController _blinkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
  final _rand = math.Random();

  @override
  void initState() {
    super.initState();
    _scheduleNextBlink();
  }

  void _scheduleNextBlink() {
    Future.delayed(Duration(milliseconds: 2400 + _rand.nextInt(2600)), () async {
      if (!mounted) return;
      await _blinkController.forward();
      if (!mounted) return;
      await _blinkController.reverse();
      _scheduleNextBlink();
    });
  }

  @override
  void dispose() {
    _breathController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_breathController, _blinkController]),
      builder: (context, _) {
        final breath = 1.0 + (_breathController.value * 0.035);
        return Transform.scale(
          scale: breath,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _LeonPainter(mood: widget.mood, blink: _blinkController.value, crowned: widget.crowned),
            ),
          ),
        );
      },
    );
  }
}

class _LeonPainter extends CustomPainter {
  final LeonMood mood;
  final double blink; // 0 = open, 1 = fully closed
  final bool crowned;

  _LeonPainter({required this.mood, required this.blink, required this.crowned});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    _paintMane(canvas, center, r);
    _paintEars(canvas, center, r);
    _paintHead(canvas, center, r);
    _paintMuzzle(canvas, center, r);
    _paintEyes(canvas, center, r);
    _paintEyebrows(canvas, center, r);
    _paintNoseAndMouth(canvas, center, r);
    _paintCheeks(canvas, center, r);
    if (crowned) _paintCrown(canvas, center, r);
  }

  void _paintMane(Canvas canvas, Offset center, double r) {
    final petalCount = 14;
    final outerR = r * 0.98;
    final innerR = r * 0.72;
    for (var i = 0; i < petalCount; i++) {
      final angle = (2 * math.pi / petalCount) * i;
      final petalColor = i.isEven ? GameColors.leonMane : GameColors.leonManeDark;
      final tip = center + Offset(math.cos(angle), math.sin(angle)) * outerR;
      final baseAngle1 = angle - 0.22;
      final baseAngle2 = angle + 0.22;
      final base1 = center + Offset(math.cos(baseAngle1), math.sin(baseAngle1)) * innerR;
      final base2 = center + Offset(math.cos(baseAngle2), math.sin(baseAngle2)) * innerR;
      final path = Path()
        ..moveTo(base1.dx, base1.dy)
        ..quadraticBezierTo(tip.dx, tip.dy, base2.dx, base2.dy)
        ..close();
      canvas.drawPath(path, Paint()..color = petalColor);
    }
    canvas.drawCircle(center, innerR * 1.02, Paint()..color = GameColors.leonMane);
  }

  void _paintEars(Canvas canvas, Offset center, double r) {
    for (final side in [-1.0, 1.0]) {
      final earCenter = center + Offset(side * r * 0.52, -r * 0.62);
      canvas.drawCircle(earCenter, r * 0.2, Paint()..color = GameColors.leonFace);
      canvas.drawCircle(earCenter, r * 0.11, Paint()..color = GameColors.leonMuzzle);
    }
  }

  void _paintHead(Canvas canvas, Offset center, double r) {
    canvas.drawCircle(center, r * 0.68, Paint()..color = GameColors.leonFace);
  }

  void _paintMuzzle(Canvas canvas, Offset center, double r) {
    final muzzleCenter = center + Offset(0, r * 0.22);
    final rect = Rect.fromCenter(center: muzzleCenter, width: r * 0.78, height: r * 0.5);
    canvas.drawOval(rect, Paint()..color = GameColors.leonMuzzle);
  }

  void _paintCheeks(Canvas canvas, Offset center, double r) {
    final paint = Paint()..color = GameColors.coral.withValues(alpha: 0.35);
    canvas.drawCircle(center + Offset(-r * 0.42, r * 0.12), r * 0.1, paint);
    canvas.drawCircle(center + Offset(r * 0.42, r * 0.12), r * 0.1, paint);
  }

  void _paintEyes(Canvas canvas, Offset center, double r) {
    final eyeY = center.dy - r * 0.06;
    final eyeDx = r * 0.26;
    final openHeight = switch (mood) {
      LeonMood.excited => r * 0.22,
      LeonMood.sleepy => r * 0.05,
      _ => r * 0.16,
    };
    final height = math.max(r * 0.02, openHeight * (1 - blink));
    final width = r * 0.13;

    for (final side in [-1.0, 1.0]) {
      final eyeCenter = Offset(center.dx + side * eyeDx, eyeY);
      final rect = Rect.fromCenter(center: eyeCenter, width: width, height: height);
      canvas.drawOval(rect, Paint()..color = const Color(0xFF241335));
      if (height > r * 0.06) {
        canvas.drawCircle(
          eyeCenter + Offset(width * 0.18, -height * 0.22),
          width * 0.18,
          Paint()..color = Colors.white.withValues(alpha: 0.9),
        );
      }
    }
  }

  void _paintEyebrows(Canvas canvas, Offset center, double r) {
    if (mood != LeonMood.excited && mood != LeonMood.proud) return;
    final paint = Paint()
      ..color = GameColors.leonManeDark
      ..strokeWidth = r * 0.035
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final side in [-1.0, 1.0]) {
      final base = center + Offset(side * r * 0.26, -r * 0.24);
      final path = Path()
        ..moveTo(base.dx - side * r * 0.09, base.dy + r * 0.02)
        ..quadraticBezierTo(base.dx, base.dy - r * 0.06, base.dx + side * r * 0.09, base.dy);
      canvas.drawPath(path, paint);
    }
  }

  void _paintNoseAndMouth(Canvas canvas, Offset center, double r) {
    final noseCenter = center + Offset(0, r * 0.06);
    final nosePath = Path()
      ..moveTo(noseCenter.dx - r * 0.07, noseCenter.dy)
      ..lineTo(noseCenter.dx + r * 0.07, noseCenter.dy)
      ..lineTo(noseCenter.dx, noseCenter.dy + r * 0.06)
      ..close();
    canvas.drawPath(nosePath, Paint()..color = GameColors.leonNose);

    final mouthPaint = Paint()
      ..color = GameColors.leonNose
      ..strokeWidth = r * 0.035
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final mouthTop = noseCenter + Offset(0, r * 0.05);
    canvas.drawLine(mouthTop, mouthTop + Offset(0, r * 0.06), mouthPaint);

    switch (mood) {
      case LeonMood.excited:
        final rect = Rect.fromCenter(center: mouthTop + Offset(0, r * 0.14), width: r * 0.32, height: r * 0.22);
        canvas.drawArc(rect, 0.15, math.pi - 0.3, false, mouthPaint);
        final tonguePaint = Paint()..color = GameColors.coral;
        canvas.drawOval(
          Rect.fromCenter(center: mouthTop + Offset(0, r * 0.2), width: r * 0.14, height: r * 0.1),
          tonguePaint,
        );
      case LeonMood.sleepy:
        final path = Path()
          ..moveTo(mouthTop.dx - r * 0.08, mouthTop.dy + r * 0.08)
          ..quadraticBezierTo(mouthTop.dx, mouthTop.dy + r * 0.12, mouthTop.dx + r * 0.08, mouthTop.dy + r * 0.08);
        canvas.drawPath(path, mouthPaint);
      case LeonMood.happy:
      case LeonMood.proud:
        for (final side in [-1.0, 1.0]) {
          final path = Path()
            ..moveTo(mouthTop.dx, mouthTop.dy + r * 0.06)
            ..quadraticBezierTo(
              mouthTop.dx + side * r * 0.14,
              mouthTop.dy + r * 0.06,
              mouthTop.dx + side * r * 0.16,
              mouthTop.dy - r * 0.02,
            );
          canvas.drawPath(path, mouthPaint);
        }
    }
  }

  void _paintCrown(Canvas canvas, Offset center, double r) {
    final base = center + Offset(0, -r * 0.92);
    final w = r * 0.4;
    final h = r * 0.22;
    final path = Path()
      ..moveTo(base.dx - w / 2, base.dy + h)
      ..lineTo(base.dx - w / 2, base.dy + h * 0.3)
      ..lineTo(base.dx - w / 4, base.dy + h * 0.7)
      ..lineTo(base.dx, base.dy)
      ..lineTo(base.dx + w / 4, base.dy + h * 0.7)
      ..lineTo(base.dx + w / 2, base.dy + h * 0.3)
      ..lineTo(base.dx + w / 2, base.dy + h)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(colors: GameColors.goldGradient).createShader(path.getBounds())
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(Offset(base.dx, base.dy + h * 0.1), r * 0.035, Paint()..color = GameColors.coral);
  }

  @override
  bool shouldRepaint(covariant _LeonPainter oldDelegate) {
    return oldDelegate.mood != mood || oldDelegate.blink != blink || oldDelegate.crowned != crowned;
  }
}
