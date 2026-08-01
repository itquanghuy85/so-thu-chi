import { Column, CreateDateColumn, Entity, JoinColumn, ManyToOne, PrimaryGeneratedColumn } from 'typeorm';
import { Workspace } from '../../workspaces/entities/workspace.entity';
import { Category } from '../../categories/entities/category.entity';
import { Vault } from '../../vaults/entities/vault.entity';
import { Customer } from '../../customers/entities/customer.entity';
import { User } from '../../users/entities/user.entity';
import { bigintTransformer } from '../../../common/utils/bigint.transformer';
import type { TransactionTypeDto } from '../../transactions/dto/create-transaction.dto';

export type RecurringFrequency = 'daily' | 'weekly' | 'monthly';

/// A template for a transaction that repeats on a schedule (Mục — "Giao
/// dịch định kỳ"), e.g. rent, staff salary. There's no cron/scheduler
/// infrastructure in this backend (same constraint as the weekly quest in
/// gamification) — due occurrences are instead materialized lazily,
/// whenever a client calls `POST /workspaces/:id/recurring/run-due`
/// (mobile calls this once on Dashboard load). `nextRunDate` advances past
/// "now" each time, so it's safe to call as often as the client wants.
@Entity('recurring_transactions')
export class RecurringTransaction {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'workspace_id' })
  workspaceId: string;

  @ManyToOne(() => Workspace, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'workspace_id' })
  workspace: Workspace;

  @Column({ type: 'varchar', length: 20 })
  type: TransactionTypeDto;

  @Column({ type: 'bigint', transformer: bigintTransformer })
  amount: number;

  @Column({ name: 'category_id', type: 'uuid', nullable: true })
  categoryId: string | null;

  @ManyToOne(() => Category, { onDelete: 'SET NULL', nullable: true })
  @JoinColumn({ name: 'category_id' })
  category: Category | null;

  @Column({ name: 'from_vault_id', type: 'uuid', nullable: true })
  fromVaultId: string | null;

  @ManyToOne(() => Vault, { onDelete: 'CASCADE', nullable: true })
  @JoinColumn({ name: 'from_vault_id' })
  fromVault: Vault | null;

  @Column({ name: 'to_vault_id', type: 'uuid', nullable: true })
  toVaultId: string | null;

  @ManyToOne(() => Vault, { onDelete: 'CASCADE', nullable: true })
  @JoinColumn({ name: 'to_vault_id' })
  toVault: Vault | null;

  @Column({ name: 'customer_id', type: 'uuid', nullable: true })
  customerId: string | null;

  @ManyToOne(() => Customer, { onDelete: 'CASCADE', nullable: true })
  @JoinColumn({ name: 'customer_id' })
  customer: Customer | null;

  @Column({ type: 'text', nullable: true })
  note: string | null;

  @Column({ type: 'varchar', length: 10 })
  frequency: RecurringFrequency;

  @Column({ name: 'next_run_date', type: 'timestamptz' })
  nextRunDate: Date;

  @Column({ type: 'boolean', default: true })
  active: boolean;

  @Column({ name: 'created_by' })
  createdBy: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'created_by' })
  createdByUser: User;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
