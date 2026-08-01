import { Column, CreateDateColumn, Entity, JoinColumn, ManyToOne, PrimaryGeneratedColumn } from 'typeorm';
import { User } from '../../users/entities/user.entity';

export type WorkspaceType = 'shop' | 'family';

@Entity('workspaces')
export class Workspace {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'owner_id' })
  ownerId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'owner_id' })
  owner: User;

  @Column()
  name: string;

  @Column({ type: 'varchar', length: 20 })
  type: WorkspaceType;

  @Column({ name: 'invite_code', type: 'varchar', nullable: true, unique: true })
  inviteCode: string | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
