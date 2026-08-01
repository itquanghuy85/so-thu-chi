import { Column, CreateDateColumn, Entity, PrimaryColumn } from 'typeorm';

/// Records that a user already claimed the reward for a given quest in a
/// given period (`period_key`, e.g. `2026-W31` for the ISO week), so
/// `POST /gamification/claim-quest` can't be called twice for the same
/// week. The quest's progress/window itself is computed on the fly in
/// `GamificationService` (Mục 9 "Quests") rather than stored — see
/// backend/README.md "Gamification notes" for why (no cron infra to
/// re-seed a recurring quest row every week).
@Entity('quest_claims')
export class QuestClaim {
  @PrimaryColumn({ name: 'workspace_id' })
  workspaceId: string;

  @PrimaryColumn({ name: 'user_id' })
  userId: string;

  @PrimaryColumn({ name: 'quest_key' })
  questKey: string;

  @PrimaryColumn({ name: 'period_key' })
  periodKey: string;

  @CreateDateColumn({ name: 'claimed_at' })
  claimedAt: Date;
}
