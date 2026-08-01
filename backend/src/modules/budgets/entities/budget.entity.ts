import { Column, CreateDateColumn, Entity, JoinColumn, ManyToOne, PrimaryGeneratedColumn } from 'typeorm';
import { Workspace } from '../../workspaces/entities/workspace.entity';
import { Category } from '../../categories/entities/category.entity';
import { bigintTransformer } from '../../../common/utils/bigint.transformer';

/// A monthly spending limit (Mục — "Ngân sách"). `categoryId: null` means an
/// overall "tổng chi tiêu" budget covering every expense category combined.
/// There's no `period` column: a budget always represents "this month's
/// limit" and is compared against the *current* calendar month's actual
/// spend whenever it's read (see BudgetsService.list) — editing the limit
/// takes effect immediately rather than needing a new row per month.
@Entity('budgets')
export class Budget {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'workspace_id' })
  workspaceId: string;

  @ManyToOne(() => Workspace, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'workspace_id' })
  workspace: Workspace;

  @Column({ name: 'category_id', type: 'uuid', nullable: true })
  categoryId: string | null;

  @ManyToOne(() => Category, { onDelete: 'CASCADE', nullable: true })
  @JoinColumn({ name: 'category_id' })
  category: Category | null;

  @Column({ name: 'limit_amount', type: 'bigint', transformer: bigintTransformer })
  limitAmount: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
