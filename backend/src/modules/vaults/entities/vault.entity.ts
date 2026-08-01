import { Column, CreateDateColumn, Entity, JoinColumn, ManyToOne, PrimaryGeneratedColumn } from 'typeorm';
import { Workspace } from '../../workspaces/entities/workspace.entity';
import { bigintTransformer } from '../../../common/utils/bigint.transformer';

export type VaultType = 'cash' | 'bank' | 'ewallet' | 'debt_customer' | 'owner_wallet' | 'virtual';

@Entity('vaults')
export class Vault {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'workspace_id' })
  workspaceId: string;

  @ManyToOne(() => Workspace, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'workspace_id' })
  workspace: Workspace;

  @Column()
  name: string;

  @Column({ type: 'varchar', length: 20 })
  type: VaultType;

  @Column({ name: 'current_balance', type: 'bigint', default: 0, transformer: bigintTransformer })
  currentBalance: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
