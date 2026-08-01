/// Mục 9 "Gamification hóa": XP/level/weekly-quest/achievements profile for
/// the current user within a workspace.
class GamificationProfile {
  final int xp;
  final int level;
  final int xpCurrentLevelFloor;
  final int xpNextLevel;
  final WeeklyQuest quest;
  final List<Achievement> achievements;

  const GamificationProfile({
    required this.xp,
    required this.level,
    required this.xpCurrentLevelFloor,
    required this.xpNextLevel,
    required this.quest,
    required this.achievements,
  });

  /// 0.0–1.0 progress within the current level's XP band.
  double get levelProgress {
    final span = xpNextLevel - xpCurrentLevelFloor;
    if (span <= 0) return 1;
    return ((xp - xpCurrentLevelFloor) / span).clamp(0, 1).toDouble();
  }

  factory GamificationProfile.fromJson(Map<String, dynamic> json) {
    return GamificationProfile(
      xp: json['xp'] as int,
      level: json['level'] as int,
      xpCurrentLevelFloor: json['xp_current_level_floor'] as int,
      xpNextLevel: json['xp_next_level'] as int,
      quest: WeeklyQuest.fromJson(json['quest'] as Map<String, dynamic>),
      achievements: (json['achievements'] as List<dynamic>)
          .map((e) => Achievement.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class WeeklyQuest {
  final String key;
  final String description;
  final int target;
  final int progress;
  final int rewardXp;
  final bool claimable;
  final bool claimed;

  const WeeklyQuest({
    required this.key,
    required this.description,
    required this.target,
    required this.progress,
    required this.rewardXp,
    required this.claimable,
    required this.claimed,
  });

  factory WeeklyQuest.fromJson(Map<String, dynamic> json) {
    return WeeklyQuest(
      key: json['key'] as String,
      description: json['description'] as String,
      target: json['target'] as int,
      progress: json['progress'] as int,
      rewardXp: json['reward_xp'] as int,
      claimable: json['claimable'] as bool,
      claimed: json['claimed'] as bool,
    );
  }
}

class Achievement {
  final String id;
  final String key;
  final String name;
  final String description;
  final bool unlocked;
  final DateTime? unlockedAt;

  const Achievement({
    required this.id,
    required this.key,
    required this.name,
    required this.description,
    required this.unlocked,
    required this.unlockedAt,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] as String,
      key: json['key'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      unlocked: json['unlocked'] as bool,
      unlockedAt: json['unlocked_at'] == null ? null : DateTime.parse(json['unlocked_at'] as String),
    );
  }
}
