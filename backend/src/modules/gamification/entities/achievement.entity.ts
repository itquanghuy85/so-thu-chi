import { Column, Entity, JoinColumn, ManyToOne, PrimaryGeneratedColumn } from 'typeorm';
import { Workspace } from '../../workspaces/entities/workspace.entity';

/// Seeded per workspace (like default categories) — Mục 9 "Achievements &
/// Outfits". The outfit/wardrobe half of that spec line is out of scope
/// this pass (see backend/README.md); `key` is a stable code the unlock
/// checker matches against, `criteria` is unused metadata kept for parity
/// with the original schema design.
@Entity('achievements')
export class Achievement {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'workspace_id' })
  workspaceId: string;

  @ManyToOne(() => Workspace, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'workspace_id' })
  workspace: Workspace;

  @Column({ type: 'varchar', length: 40 })
  key: string;

  @Column()
  name: string;

  @Column({ type: 'text', nullable: true })
  description: string | null;
}
