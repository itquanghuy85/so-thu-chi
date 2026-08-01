import { Column, CreateDateColumn, Entity, JoinColumn, ManyToOne, PrimaryGeneratedColumn } from 'typeorm';
import { Workspace } from '../../workspaces/entities/workspace.entity';
import { User } from '../../users/entities/user.entity';

export interface VaultSnapshotEntry {
  vault_id: string;
  name: string;
  balance: number;
}

/// A work shift (Mục — "Ca làm việc"): a person "opens" a shift (snapshots
/// every real-money vault's balance), works normally (transactions during
/// the shift are just regular transactions, not tagged to the shift), then
/// "closes" it (snapshots balances again). ShiftsService derives the
/// shift's income/expense summary by querying transactions created in the
/// [openedAt, closedAt) window — no separate ledger needed.
@Entity('shifts')
export class Shift {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'workspace_id' })
  workspaceId: string;

  @ManyToOne(() => Workspace, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'workspace_id' })
  workspace: Workspace;

  @Column({ name: 'user_id' })
  userId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @CreateDateColumn({ name: 'opened_at' })
  openedAt: Date;

  @Column({ name: 'closed_at', type: 'timestamptz', nullable: true })
  closedAt: Date | null;

  @Column({ name: 'opening_snapshot', type: 'jsonb' })
  openingSnapshot: VaultSnapshotEntry[];

  @Column({ name: 'closing_snapshot', type: 'jsonb', nullable: true })
  closingSnapshot: VaultSnapshotEntry[] | null;

  @Column({ type: 'text', nullable: true })
  note: string | null;
}
