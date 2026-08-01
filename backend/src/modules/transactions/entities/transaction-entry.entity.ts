import { Column, Entity, JoinColumn, ManyToOne, PrimaryGeneratedColumn } from 'typeorm';
import { Vault } from '../../vaults/entities/vault.entity';
import { bigintTransformer } from '../../../common/utils/bigint.transformer';
import { Transaction } from './transaction.entity';

export type EntrySide = 'D' | 'C';

/**
 * Pure audit/history record of the double-entry postings for a Transaction.
 * NOTE: vault.current_balance is updated directly by TransactionsService as
 * transactions are created/voided — it is NOT derived by summing these rows.
 */
@Entity('transaction_entries')
export class TransactionEntry {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'transaction_id' })
  transactionId: string;

  @ManyToOne(() => Transaction, (transaction) => transaction.entries, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'transaction_id' })
  transaction: Transaction;

  @Column({ name: 'vault_id' })
  vaultId: string;

  @ManyToOne(() => Vault, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'vault_id' })
  vault: Vault;

  @Column({ type: 'char', length: 1 })
  side: EntrySide;

  @Column({ type: 'bigint', transformer: bigintTransformer })
  amount: number;
}
