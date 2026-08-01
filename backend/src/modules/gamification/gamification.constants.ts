import type { XpAction } from './entities/xp-event.entity';

/// XP amounts and daily caps per Mục 9 "XP actions". `dailyCap` is the max
/// total XP `awardXp` will grant for that action in a rolling calendar day
/// (`null` = uncapped).
export const XP_RULES: Record<XpAction, { amount: number; dailyCap: number | null }> = {
  transaction_create: { amount: 5, dailyCap: 50 },
  reconcile_match: { amount: 30, dailyCap: null },
  debt_decrease: { amount: 20, dailyCap: null },
  member_invite: { amount: 50, dailyCap: null },
  voice_input: { amount: 5, dailyCap: 25 },
  quest_reward: { amount: 0, dailyCap: null }, // amount passed explicitly per-quest
};

/// Level curve (Mục 9: "XP cần = 100 * level^2"). Everyone starts at level
/// 1 with 0 XP; `xpRequiredForLevel(level)` is the *cumulative* XP needed
/// to reach `level`, using `level - 1` in the formula so level 2 needs a
/// reachable 100 XP (not 400) — level 3 needs 400, level 4 needs 900, etc.
export function xpRequiredForLevel(level: number): number {
  if (level <= 1) return 0;
  const n = level - 1;
  return 100 * n * n;
}

export function levelForXp(xp: number): number {
  let level = 1;
  while (xp >= xpRequiredForLevel(level + 1)) level++;
  return level;
}

/// Single default weekly quest (Mục 9 example) — see gamification.service.ts
/// for how its progress/window is computed dynamically instead of stored.
export const WEEKLY_QUEST = {
  key: 'weekly_transactions_20',
  description: 'Tạo 20 giao dịch trong tuần',
  target: 20,
  rewardXp: 100,
};

export const DEFAULT_ACHIEVEMENTS: { key: string; name: string; description: string }[] = [
  { key: 'founder', name: 'Người mở đường', description: 'Tạo không gian làm việc đầu tiên' },
  { key: 'ten_transactions', name: '10 giao dịch đầu tiên', description: 'Tạo 10 giao dịch trong không gian làm việc này' },
  { key: 'perfect_reconcile', name: 'Kiểm kê hoàn hảo', description: 'Kiểm kê khớp sổ sách lần đầu tiên' },
];
