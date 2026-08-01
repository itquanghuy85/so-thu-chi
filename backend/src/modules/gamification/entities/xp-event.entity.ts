import { Column, CreateDateColumn, Entity, PrimaryGeneratedColumn } from 'typeorm';

export type XpAction = 'transaction_create' | 'reconcile_match' | 'debt_decrease' | 'member_invite' | 'voice_input' | 'quest_reward';

/// Append-only XP award log (Mục 9 "XP actions"). Recording every award
/// (not just the running `user_xp` total) is what lets `awardXp` enforce
/// the daily caps ("Tạo giao dịch: +5 XP (max 50/ngày)") with a simple
/// SUM query instead of a separate counter that could drift.
@Entity('xp_events')
export class XpEvent {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'workspace_id' })
  workspaceId: string;

  @Column({ name: 'user_id' })
  userId: string;

  @Column({ type: 'varchar', length: 30 })
  action: XpAction;

  @Column({ type: 'int' })
  amount: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
