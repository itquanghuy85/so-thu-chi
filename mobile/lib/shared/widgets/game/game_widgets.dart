import 'package:flutter/material.dart';

import '../../../core/constants/game_colors.dart';

/// Shared building blocks for the "Game Leon" visual style — kept in one
/// file since they're small and always used together (Dashboard, Thành
/// tích screen). Each widget owns its own glow/gradient chrome so screens
/// composing them stay declarative.

/// Frosted dark card with a subtle neon border — the base surface every
/// game-styled panel sits on.
class GameCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final VoidCallback? onTap;

  const GameCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.borderColor, this.onTap});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: GameColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor ?? GameColors.surfaceBorder, width: 1.4),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 6)),
          if (borderColor != null) BoxShadow(color: borderColor!.withValues(alpha: 0.25), blurRadius: 16, spreadRadius: -4),
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(borderRadius: BorderRadius.circular(18), onTap: onTap, child: card);
  }
}

/// Hexagon-ish glowing level badge — "Lv.N" in a gem shape.
class GameLevelBadge extends StatelessWidget {
  final int level;
  final double size;

  const GameLevelBadge({super.key, required this.level, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: GameColors.goldGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [
          BoxShadow(color: GameColors.gold.withValues(alpha: 0.55), blurRadius: 18, spreadRadius: 1),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('LV', style: TextStyle(color: const Color(0xFF4A2E00).withValues(alpha: 0.7), fontSize: size * 0.16, fontWeight: FontWeight.w800, letterSpacing: 1)),
          Text('$level', style: const TextStyle(color: Color(0xFF4A2E00), fontSize: 20, fontWeight: FontWeight.w900, height: 1)),
        ],
      ),
    );
  }
}

/// Glowing gradient XP progress bar with a shimmering edge.
class GameXpBar extends StatelessWidget {
  final double progress; // 0..1
  final String label;

  const GameXpBar({super.key, required this.progress, required this.label});

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 16,
            color: GameColors.surfaceLight,
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: clamped,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: GameColors.xpBarGradient),
                      boxShadow: [BoxShadow(color: GameColors.cyan.withValues(alpha: 0.7), blurRadius: 10)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: GameColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// Big chunky circular "arcade button" used for quick actions — 3D bevel
/// via layered light/dark shadow offsets instead of a flat Material button.
class GameActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const GameActionButton({super.key, required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [color.withValues(alpha: 0.95), color], begin: Alignment.topLeft, end: Alignment.bottomRight),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 14, offset: const Offset(0, 4)),
                BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 3)),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: GameColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// A vault rendered as a glowing "treasure chest" tile.
class GameChestCard extends StatelessWidget {
  final String name;
  final String balanceLabel;
  final double progress;
  final Color accent;
  final VoidCallback onTap;

  const GameChestCard({
    super.key,
    required this.name,
    required this.balanceLabel,
    required this.progress,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GameCard(
      onTap: onTap,
      borderColor: accent.withValues(alpha: 0.6),
      padding: const EdgeInsets.all(14),
      child: SizedBox(
        width: 156,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    gradient: const LinearGradient(colors: GameColors.chestGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                    border: Border.all(color: GameColors.gold, width: 1.4),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.inventory_2_rounded, color: GameColors.gold, size: 17),
                ),
                const Spacer(),
                Icon(Icons.circle, size: 8, color: accent),
              ],
            ),
            const SizedBox(height: 10),
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: GameColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 2),
            Text(balanceLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: GameColors.gold, fontWeight: FontWeight.w800, fontSize: 14, shadows: [Shadow(color: GameColors.gold.withValues(alpha: 0.5), blurRadius: 8)])),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.05, 1.0),
                minHeight: 5,
                backgroundColor: GameColors.surfaceLight,
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section title styled for the dark game background.
class GameSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const GameSectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: GameColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
        if (trailing != null) trailing!,
      ],
    );
  }
}
