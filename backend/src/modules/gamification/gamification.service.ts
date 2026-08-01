import { Injectable } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { UserXp } from './entities/user-xp.entity';
import { XpEvent } from './entities/xp-event.entity';
import type { XpAction } from './entities/xp-event.entity';
import { Achievement } from './entities/achievement.entity';
import { UserAchievement } from './entities/user-achievement.entity';
import { QuestClaim } from './entities/quest-claim.entity';
import { Transaction } from '../transactions/entities/transaction.entity';
import { XP_RULES, WEEKLY_QUEST, levelForXp, xpRequiredForLevel } from './gamification.constants';
import { AppException } from '../../common/exceptions/app.exception';
import { assertWorkspaceMember } from '../../common/utils/workspace-access.util';

function startOfWeek(now: Date): Date {
  const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const diffToMonday = startOfDay.getDay() === 0 ? 6 : startOfDay.getDay() - 1;
  startOfDay.setDate(startOfDay.getDate() - diffToMonday);
  return startOfDay;
}

function isoWeekKey(now: Date): string {
  // Simple, stable per-Monday key — doesn't need to be strictly
  // ISO-8601-compliant, just unique per week and consistent between the
  // progress check and the claim.
  const monday = startOfWeek(now);
  return `${monday.getFullYear()}-${monday.getMonth() + 1}-${monday.getDate()}`;
}

@Injectable()
export class GamificationService {
  constructor(@InjectDataSource() private readonly dataSource: DataSource) {}

  /// Grants XP for [action] (respecting the daily cap in XP_RULES),
  /// updates the cached `user_xp` total/level, and checks for any
  /// achievement unlocks that action might trigger. Called from other
  /// modules (Transactions, Vaults, Workspaces) right after their own
  /// action succeeds — never blocks/throws on gamification failures
  /// mattering to the caller's core action.
  async awardXp(workspaceId: string, userId: string, action: XpAction, amountOverride?: number): Promise<void> {
    const rule = XP_RULES[action];
    const amount = amountOverride ?? rule.amount;
    if (amount <= 0) return;

    const eventsRepo = this.dataSource.getRepository(XpEvent);
    let awarded = amount;

    if (rule.dailyCap != null) {
      const startOfDay = new Date();
      startOfDay.setHours(0, 0, 0, 0);
      const raw = await eventsRepo
        .createQueryBuilder('e')
        .select('COALESCE(SUM(e.amount), 0)', 'sum')
        .where('e.workspaceId = :workspaceId', { workspaceId })
        .andWhere('e.userId = :userId', { userId })
        .andWhere('e.action = :action', { action })
        .andWhere('e.createdAt >= :startOfDay', { startOfDay })
        .getRawOne<{ sum: string }>();
      const already = parseInt(raw?.sum ?? '0', 10) || 0;
      awarded = Math.max(0, Math.min(amount, rule.dailyCap - already));
      if (awarded <= 0) return;
    }

    await eventsRepo.save(eventsRepo.create({ workspaceId, userId, action, amount: awarded }));

    const userXpRepo = this.dataSource.getRepository(UserXp);
    let userXp = await userXpRepo.findOne({ where: { workspaceId, userId } });
    if (!userXp) {
      userXp = userXpRepo.create({ workspaceId, userId, xp: 0, level: 1 });
    }
    userXp.xp += awarded;
    userXp.level = levelForXp(userXp.xp);
    await userXpRepo.save(userXp);

    await this.checkAchievements(workspaceId, userId);
  }

  /// Awards the "Người mở đường" achievement immediately — called from
  /// WorkspacesService right after a new workspace (and its default
  /// achievement rows) is created.
  async unlockFounderAchievement(workspaceId: string, userId: string): Promise<void> {
    await this.unlockIfPresent(workspaceId, userId, 'founder');
  }

  private async checkAchievements(workspaceId: string, userId: string): Promise<void> {
    const transactionCount = await this.dataSource
      .getRepository(Transaction)
      .count({ where: { workspaceId, createdBy: userId } });
    if (transactionCount >= 10) {
      await this.unlockIfPresent(workspaceId, userId, 'ten_transactions');
    }
  }

  async unlockReconcileAchievementIfFirst(workspaceId: string, userId: string): Promise<void> {
    await this.unlockIfPresent(workspaceId, userId, 'perfect_reconcile');
  }

  private async unlockIfPresent(workspaceId: string, userId: string, key: string): Promise<void> {
    const achievement = await this.dataSource.getRepository(Achievement).findOne({ where: { workspaceId, key } });
    if (!achievement) return;
    const userAchievementsRepo = this.dataSource.getRepository(UserAchievement);
    const existing = await userAchievementsRepo.findOne({ where: { userId, achievementId: achievement.id } });
    if (existing) return;
    await userAchievementsRepo.save(userAchievementsRepo.create({ userId, achievementId: achievement.id, workspaceId }));
  }

  async getProfile(userId: string, workspaceId: string) {
    await assertWorkspaceMember(this.dataSource, workspaceId, userId);

    const userXp = await this.dataSource.getRepository(UserXp).findOne({ where: { workspaceId, userId } });
    const xp = userXp?.xp ?? 0;
    const level = userXp?.level ?? 1;

    const now = new Date();
    const weekStart = startOfWeek(now);
    const weekEnd = new Date(weekStart);
    weekEnd.setDate(weekEnd.getDate() + 7);
    const periodKey = isoWeekKey(now);

    const progress = await this.dataSource
      .getRepository(Transaction)
      .createQueryBuilder('t')
      .where('t.workspaceId = :workspaceId', { workspaceId })
      .andWhere('t.createdBy = :userId', { userId })
      .andWhere('t.createdAt >= :weekStart', { weekStart })
      .andWhere('t.createdAt < :weekEnd', { weekEnd })
      .getCount();

    const claimed = await this.dataSource
      .getRepository(QuestClaim)
      .findOne({ where: { workspaceId, userId, questKey: WEEKLY_QUEST.key, periodKey } });

    const achievements = await this.dataSource.getRepository(Achievement).find({ where: { workspaceId }, order: { name: 'ASC' } });
    const unlocked = await this.dataSource.getRepository(UserAchievement).find({ where: { userId, workspaceId } });
    const unlockedMap = new Map(unlocked.map((u) => [u.achievementId, u.unlockedAt]));

    return {
      xp,
      level,
      xp_current_level_floor: xpRequiredForLevel(level),
      xp_next_level: xpRequiredForLevel(level + 1),
      quest: {
        key: WEEKLY_QUEST.key,
        description: WEEKLY_QUEST.description,
        target: WEEKLY_QUEST.target,
        progress: Math.min(progress, WEEKLY_QUEST.target),
        reward_xp: WEEKLY_QUEST.rewardXp,
        claimable: progress >= WEEKLY_QUEST.target && !claimed,
        claimed: !!claimed,
      },
      achievements: achievements.map((a) => ({
        id: a.id,
        key: a.key,
        name: a.name,
        description: a.description,
        unlocked: unlockedMap.has(a.id),
        unlocked_at: unlockedMap.get(a.id) ?? null,
      })),
    };
  }

  async claimQuest(userId: string, workspaceId: string) {
    await assertWorkspaceMember(this.dataSource, workspaceId, userId);

    const now = new Date();
    const weekStart = startOfWeek(now);
    const weekEnd = new Date(weekStart);
    weekEnd.setDate(weekEnd.getDate() + 7);
    const periodKey = isoWeekKey(now);

    const claimsRepo = this.dataSource.getRepository(QuestClaim);
    const existing = await claimsRepo.findOne({ where: { workspaceId, userId, questKey: WEEKLY_QUEST.key, periodKey } });
    if (existing) {
      throw new AppException('CONFLICT', 'Bạn đã nhận thưởng nhiệm vụ này rồi');
    }

    const progress = await this.dataSource
      .getRepository(Transaction)
      .createQueryBuilder('t')
      .where('t.workspaceId = :workspaceId', { workspaceId })
      .andWhere('t.createdBy = :userId', { userId })
      .andWhere('t.createdAt >= :weekStart', { weekStart })
      .andWhere('t.createdAt < :weekEnd', { weekEnd })
      .getCount();

    if (progress < WEEKLY_QUEST.target) {
      throw new AppException('VALIDATION_ERROR', 'Chưa hoàn thành nhiệm vụ này');
    }

    await claimsRepo.save(claimsRepo.create({ workspaceId, userId, questKey: WEEKLY_QUEST.key, periodKey }));
    await this.awardXp(workspaceId, userId, 'quest_reward', WEEKLY_QUEST.rewardXp);

    return this.getProfile(userId, workspaceId);
  }
}
