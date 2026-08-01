import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/game_colors.dart';
import '../../../core/errors/api_exception.dart';
import '../../../shared/providers/current_workspace_provider.dart';
import '../../../shared/widgets/game/game_widgets.dart';
import '../../../shared/widgets/leon_mascot.dart';
import '../data/gamification_repository.dart';
import '../domain/gamification_profile.dart';

/// "Game Leon" skin for the Thành tích screen (Mục 16.2) — Leon front and
/// center, the weekly quest presented as a mission card, achievements as
/// glowing medals. Same data/providers as the Classic version
/// (`gamification_screen.dart`), purely a different presentation.
class GameGamificationBody extends ConsumerWidget {
  final GamificationProfile profile;

  const GameGamificationBody({super.key, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: GameColors.bgGradient, begin: Alignment.topCenter, end: Alignment.bottomCenter),
      ),
      child: RefreshIndicator(
        color: GameColors.cyan,
        backgroundColor: GameColors.surface,
        onRefresh: () async => ref.invalidate(gamificationProfileProvider),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            SafeArea(
              bottom: false,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: GameColors.textPrimary),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Text('Hành trình của Leon', style: TextStyle(color: GameColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  LeonMascot(
                    size: 140,
                    mood: profile.quest.claimable ? LeonMood.excited : (profile.levelProgress > 0.7 ? LeonMood.proud : LeonMood.happy),
                    crowned: profile.level >= 5,
                  ),
                  Positioned(bottom: 0, right: -4, child: GameLevelBadge(level: profile.level, size: 46)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            GameCard(
              borderColor: GameColors.cyan.withValues(alpha: 0.5),
              child: GameXpBar(progress: profile.levelProgress, label: '${profile.xp} / ${profile.xpNextLevel} XP đến cấp ${profile.level + 1}'),
            ),
            const SizedBox(height: 22),
            const GameSectionHeader(title: 'Nhiệm vụ tuần này'),
            const SizedBox(height: 10),
            _GameQuestCard(quest: profile.quest),
            const SizedBox(height: 22),
            const GameSectionHeader(title: 'Huy chương'),
            const SizedBox(height: 10),
            _GameAchievementGrid(achievements: profile.achievements),
          ],
        ),
      ),
    );
  }
}

class _GameQuestCard extends ConsumerStatefulWidget {
  final WeeklyQuest quest;

  const _GameQuestCard({required this.quest});

  @override
  ConsumerState<_GameQuestCard> createState() => _GameQuestCardState();
}

class _GameQuestCardState extends ConsumerState<_GameQuestCard> with SingleTickerProviderStateMixin {
  bool _claiming = false;
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _claim() async {
    setState(() => _claiming = true);
    try {
      final workspaceId = ref.read(currentWorkspaceIdProvider);
      await ref.read(gamificationRepositoryProvider).claimQuest(workspaceId);
      ref.invalidate(gamificationProfileProvider);
    } catch (e) {
      final message = e is ApiException ? e.message : 'Không thể nhận thưởng';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quest = widget.quest;
    final progress = (quest.progress / quest.target).clamp(0, 1).toDouble();
    return GameCard(
      borderColor: quest.claimable ? GameColors.gold : GameColors.surfaceBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [GameColors.violet, GameColors.magenta])),
                alignment: Alignment.center,
                child: const Icon(Icons.flag_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(quest.description, style: const TextStyle(color: GameColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('Phần thưởng: +${quest.rewardXp} XP', style: const TextStyle(color: GameColors.gold, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GameXpBar(progress: progress, label: '${quest.progress}/${quest.target}'),
          if (quest.claimed) ...[
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(Icons.check_circle, color: GameColors.lime, size: 16),
                SizedBox(width: 6),
                Text('Đã nhận thưởng tuần này', style: TextStyle(color: GameColors.lime, fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
          ] else if (quest.claimable) ...[
            const SizedBox(height: 14),
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) => Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: GameColors.gold.withValues(alpha: 0.3 + _pulse.value * 0.35), blurRadius: 16 + _pulse.value * 8)],
                ),
                child: child,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _claiming ? null : _claim,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GameColors.gold,
                    foregroundColor: const Color(0xFF4A2E00),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _claiming
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Nhận thưởng', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GameAchievementGrid extends StatelessWidget {
  final List<Achievement> achievements;

  const _GameAchievementGrid({required this.achievements});

  @override
  Widget build(BuildContext context) {
    if (achievements.isEmpty) {
      return const GameCard(child: Text('Chưa có huy chương nào.', style: TextStyle(color: GameColors.textSecondary)));
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: achievements.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 0.82),
      itemBuilder: (context, index) => _GameMedal(achievement: achievements[index]),
    );
  }
}

class _GameMedal extends StatelessWidget {
  final Achievement achievement;

  const _GameMedal({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;
    final color = unlocked ? GameColors.forKey(achievement.key) : GameColors.surfaceBorder;
    return Column(
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: unlocked
                ? LinearGradient(colors: [color.withValues(alpha: 0.9), color], begin: Alignment.topLeft, end: Alignment.bottomRight)
                : null,
            color: unlocked ? null : GameColors.surface,
            border: Border.all(color: unlocked ? Colors.white.withValues(alpha: 0.5) : GameColors.surfaceBorder, width: 2),
            boxShadow: unlocked ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 14, spreadRadius: 1)] : null,
          ),
          alignment: Alignment.center,
          child: Icon(
            unlocked ? Icons.military_tech_rounded : Icons.lock_outline,
            color: unlocked ? Colors.white : GameColors.textSecondary,
            size: 26,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          achievement.name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: unlocked ? GameColors.textPrimary : GameColors.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
