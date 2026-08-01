import { Column, CreateDateColumn, Entity, JoinColumn, ManyToOne, PrimaryColumn } from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { Workspace } from './workspace.entity';

export type WorkspaceRole = 'owner' | 'manager' | 'cashier' | 'member';

@Entity('workspace_members')
export class WorkspaceMember {
  @PrimaryColumn({ name: 'workspace_id' })
  workspaceId: string;

  @PrimaryColumn({ name: 'user_id' })
  userId: string;

  @ManyToOne(() => Workspace, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'workspace_id' })
  workspace: Workspace;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ type: 'varchar', length: 20, default: 'owner' })
  role: WorkspaceRole;

  @CreateDateColumn({ name: 'joined_at' })
  joinedAt: Date;
}
