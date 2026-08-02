import type { VaultType } from '../vaults/entities/vault.entity';
import type { TransactionTypeDto } from '../transactions/dto/create-transaction.dto';
import type { EntrySide } from '../transactions/entities/transaction-entry.entity';

/// Shape of the JSON produced by `BackupService.exportBackup` and consumed
/// by `BackupService.restoreBackup`. IDs here are the *original* workspace's
/// IDs — restore remaps every one of them to fresh rows, they're only used
/// to stitch relations back together within the payload itself.
export interface BackupPayload {
  backup_version: number;
  exported_at: string;
  workspace: { name: string; type: 'shop' | 'family' };
  vaults: { id: string; name: string; type: VaultType; current_balance: number }[];
  categories: { id: string; name: string; group_name: 'income' | 'expense'; icon: string | null }[];
  customers: { id: string; name: string; phone: string | null; debt_vault_id: string }[];
  transactions: {
    id: string;
    type: TransactionTypeDto;
    amount: number;
    note: string | null;
    cost_amount: number | null;
    status: string;
    created_at: string;
    category_id: string | null;
    entries: { vault_id: string; side: EntrySide; amount: number }[];
  }[];
}
