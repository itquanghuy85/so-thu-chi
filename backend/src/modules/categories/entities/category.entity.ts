import { Column, Entity, JoinColumn, ManyToOne, PrimaryGeneratedColumn } from 'typeorm';
import { Workspace } from '../../workspaces/entities/workspace.entity';

export type CategoryGroup = 'income' | 'expense';

@Entity('categories')
export class Category {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'workspace_id' })
  workspaceId: string;

  @ManyToOne(() => Workspace, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'workspace_id' })
  workspace: Workspace;

  @Column()
  name: string;

  @Column({ name: 'group_name', type: 'varchar', length: 20 })
  groupName: CategoryGroup;

  @Column({ type: 'varchar', nullable: true })
  icon: string | null;
}
