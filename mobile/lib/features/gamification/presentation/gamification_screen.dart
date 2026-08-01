import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/api_exception.dart';
import '../../../shared/providers/current_workspace_provider.dart';
import '../data/gamification_repository.dart';
import '../domain/gamification_profile.dart';

/// Mục 9 "Gamification hóa": XP/cấp độ, nhiệm vụ tuần, huy hiệu.
///
/// The spec's full "Game Leon" theme (mascot art, wardrobe, alternate
/// game-styled dashboard skin) needs illustrated character assets that
/// don't exist in this project — out of scope here (documented in
/// mobile/README.md). This screen instead surfaces the same underlying
/// XP/quest/achievement system through the app's existing Classic design
/// language (gradient header, card+shadow style, AppColors palette).
class GamificationScreen extends ConsumerWidget {
  const GamificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(gamificationProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Không thể tải dữ liệu thành tích.', textAlign: TextAlign.center),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => ref.invalidate(gamificationProfileProvider),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
        data: (profile) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(gamificationProfileProvider),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _XpHeader(profile: profile),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nhiệm vụ tuần này', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    _QuestCard(quest: profile.quest),
                    const SizedBox(height: 24),
                    const Text('Huy hiệu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    _AchievementGrid(achievements: profile.achievements),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _XpHeader extends StatelessWidget {
  final GamificationProfile profile;

  const _XpHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.headerGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 4),
                const Text('Thành tích của bạn', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                  ),
                  child: const Icon(Icons.emoji_events_rounded, color: Colors.amberAccent, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cấp độ ${profile.level}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: profile.levelProgress,
                          minHeight: 8,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          valueColor: const AlwaysStoppedAnimation(Colors.amberAccent),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${profile.xp} / ${profile.xpNextLevel} XP',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestCard extends ConsumerStatefulWidget {
  final WeeklyQuest quest;

  const _QuestCard({required this.quest});

  @override
  ConsumerState<_QuestCard> createState() => _QuestCardState();
}

class _QuestCardState extends ConsumerState<_QuestCard> {
  bool _claiming = false;

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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 20, backgroundColor: AppColors.secondary.withValues(alpha: 0.12), child: const Icon(Icons.flag_rounded, color: AppColors.secondary)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(quest.description, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('Thưởng: +${quest.rewardXp} XP', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.secondary.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation(AppColors.secondary),
            ),
          ),
          const SizedBox(height: 6),
          Text('${quest.progress}/${quest.target}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          if (quest.claimed) ...[
            const SizedBox(height: 12),
            Row(
              children: const [
                Icon(Icons.check_circle, color: AppColors.income, size: 16),
                SizedBox(width: 6),
                Text('Đã nhận thưởng tuần này', style: TextStyle(color: AppColors.income, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ] else if (quest.claimable) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _claiming ? null : _claim,
                child: _claiming
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Nhận thưởng'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AchievementGrid extends StatelessWidget {
  final List<Achievement> achievements;

  const _AchievementGrid({required this.achievements});

  @override
  Widget build(BuildContext context) {
    if (achievements.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('Chưa có huy hiệu nào.', style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: achievements.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.6,
      ),
      itemBuilder: (context, index) {
        final a = achievements[index];
        final color = a.unlocked ? AppColors.forKey(a.key) : AppColors.textSecondary;
        return Opacity(
          opacity: a.unlocked ? 1 : 0.45,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: a.unlocked
                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]
                  : null,
              border: a.unlocked ? null : Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(a.unlocked ? Icons.military_tech_rounded : Icons.lock_outline, color: color, size: 17),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      Text(a.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
