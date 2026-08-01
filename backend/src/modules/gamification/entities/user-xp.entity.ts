import { Column, Entity, PrimaryColumn } from 'typeorm';

/// Cached XP/level total per (workspace, user) — Mục 9. Kept as a running
/// total (updated by `GamificationService.awardXp`) rather than always
/// summing `xp_events`, since the profile endpoint is read far more often
/// than XP is awarded.
@Entity('user_xp')
export class UserXp {
  @PrimaryColumn({ name: 'workspace_id' })
  workspaceId: string;

  @PrimaryColumn({ name: 'user_id' })
  userId: string;

  @Column({ type: 'int', default: 0 })
  xp: number;

  @Column({ type: 'int', default: 1 })
  level: number;
}
