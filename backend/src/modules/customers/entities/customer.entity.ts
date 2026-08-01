import { Column, CreateDateColumn, Entity, JoinColumn, ManyToOne, PrimaryGeneratedColumn } from 'typeorm';
import { Workspace } from '../../workspaces/entities/workspace.entity';
import { Vault } from '../../vaults/entities/vault.entity';

@Entity('customers')
export class Customer {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'workspace_id' })
  workspaceId: string;

  @ManyToOne(() => Workspace, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'workspace_id' })
  workspace: Workspace;

  @Column()
  name: string;

  @Column({ type: 'varchar', nullable: true })
  phone: string | null;

  @Column({ name: 'debt_vault_id', unique: true })
  debtVaultId: string;

  @ManyToOne(() => Vault, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'debt_vault_id' })
  debtVault: Vault;

  @Column({ type: 'text', nullable: true })
  note: string | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
