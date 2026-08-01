import { Column, CreateDateColumn, Entity, Index, JoinColumn, ManyToOne, PrimaryGeneratedColumn } from 'typeorm';
import { Workspace } from '../../workspaces/entities/workspace.entity';
import { User } from '../../users/entities/user.entity';

export type AuditAction = 'transaction_edit' | 'transaction_void' | 'daily_closing';

/// Append-only audit trail (Mục — "sửa/xóa đều ghi log audit"). Nothing
/// ever updates or deletes a row here. `beforeData`/`afterData` are plain
/// JSON snapshots of whatever the acting service already builds as its own
/// response DTO — not a generic diffing engine, just "what it looked like
/// before" and "what it looked like after" for a human reading history.
@Entity('audit_logs')
export class AuditLog {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'workspace_id' })
  @Index()
  workspaceId: string;

  @ManyToOne(() => Workspace, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'workspace_id' })
  workspace: Workspace;

  @Column({ name: 'user_id' })
  userId: string;

  @ManyToOne(() => User, { onDelete: 'SET NULL', nullable: true })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ type: 'varchar', length: 30 })
  action: AuditAction;

  @Column({ name: 'entity_type', type: 'varchar', length: 30 })
  entityType: string;

  @Column({ name: 'entity_id' })
  @Index()
  entityId: string;

  @Column({ name: 'before_data', type: 'jsonb', nullable: true })
  beforeData: unknown | null;

  @Column({ name: 'after_data', type: 'jsonb', nullable: true })
  afterData: unknown | null;

  @Column({ type: 'text', nullable: true })
  note: string | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
