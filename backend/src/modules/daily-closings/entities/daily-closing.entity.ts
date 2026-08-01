import { Column, CreateDateColumn, Entity, Index, JoinColumn, ManyToOne, PrimaryGeneratedColumn } from 'typeorm';
import { Workspace } from '../../workspaces/entities/workspace.entity';
import { User } from '../../users/entities/user.entity';
import { bigintTransformer } from '../../../common/utils/bigint.transformer';

export interface DailyClosingEntry {
  vault_id: string;
  name: string;
  book_balance: number;
  actual_balance: number;
  variance: number;
}

/// "Chốt sổ cuối ngày" (Mục — daily closing): once per workspace per
/// calendar day, counts every vault's actual cash/balance against the
/// ledger's book balance. The actual adjustment (if any) is applied via the
/// existing `VaultsService.reconcile` per vault — this table is purely the
/// historical record of that event, not a second source of truth for
/// balances.
@Entity('daily_closings')
@Index(['workspaceId', 'closingDate'], { unique: true })
export class DailyClosing {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'workspace_id' })
  workspaceId: string;

  @ManyToOne(() => Workspace, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'workspace_id' })
  workspace: Workspace;

  @Column({ name: 'closed_by' })
  closedBy: string;

  @ManyToOne(() => User, { onDelete: 'SET NULL', nullable: true })
  @JoinColumn({ name: 'closed_by' })
  closedByUser: User;

  // Calendar date (server-local) this closing covers — one row per
  // workspace per date, enforced by the unique index above.
  @Column({ name: 'closing_date', type: 'date' })
  closingDate: string;

  @Column({ type: 'jsonb' })
  entries: DailyClosingEntry[];

  @Column({ name: 'total_variance', type: 'bigint', default: 0, transformer: bigintTransformer })
  totalVariance: number;

  @Column({ type: 'text', nullable: true })
  note: string | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
