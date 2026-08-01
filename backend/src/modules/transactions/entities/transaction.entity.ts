import { Column, CreateDateColumn, Entity, JoinColumn, ManyToOne, OneToMany, PrimaryGeneratedColumn } from 'typeorm';
import { Workspace } from '../../workspaces/entities/workspace.entity';
import { Category } from '../../categories/entities/category.entity';
import { User } from '../../users/entities/user.entity';
import { bigintTransformer } from '../../../common/utils/bigint.transformer';
import { TransactionEntry } from './transaction-entry.entity';

export type TransactionType = 'income' | 'expense' | 'transfer' | 'debt_increase' | 'debt_decrease';
export type TransactionStatus = 'completed' | 'voided';

@Entity('transactions')
export class Transaction {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'workspace_id' })
  workspaceId: string;

  @ManyToOne(() => Workspace, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'workspace_id' })
  workspace: Workspace;

  @Column({ type: 'varchar', length: 20 })
  type: TransactionType;

  @Column({ name: 'category_id', type: 'uuid', nullable: true })
  categoryId: string | null;

  @ManyToOne(() => Category, { onDelete: 'SET NULL', nullable: true })
  @JoinColumn({ name: 'category_id' })
  category: Category | null;

  @Column({ type: 'bigint', transformer: bigintTransformer })
  amount: number;

  // Giá vốn (Mục — "tính lợi nhuận theo vốn"): optional, only meaningful on
  // `income` transactions. When set, per-transaction profit is
  // `amount - costAmount`; when left blank it contributes 0 to cost, so
  // reports fall back to the original income-minus-expense profit exactly
  // as before this field existed — see ReportsService for the aggregate
  // formula.
  @Column({ name: 'cost_amount', type: 'bigint', transformer: bigintTransformer, nullable: true })
  costAmount: number | null;

  @Column({ type: 'text', nullable: true })
  note: string | null;

  @Column({ type: 'varchar', length: 20, default: 'completed' })
  status: TransactionStatus;

  @Column({ name: 'created_by' })
  createdBy: string;

  @ManyToOne(() => User, { onDelete: 'SET NULL', nullable: true })
  @JoinColumn({ name: 'created_by' })
  createdByUser: User;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @OneToMany(() => TransactionEntry, (entry) => entry.transaction)
  entries: TransactionEntry[];
}
