import { Injectable } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { Workspace } from '../workspaces/entities/workspace.entity';
import { WorkspaceMember } from '../workspaces/entities/workspace-member.entity';
import { Vault } from '../vaults/entities/vault.entity';
import { Category } from '../categories/entities/category.entity';
import { Customer } from '../customers/entities/customer.entity';
import { Transaction } from '../transactions/entities/transaction.entity';
import { TransactionEntry } from '../transactions/entities/transaction-entry.entity';
import { Achievement } from '../gamification/entities/achievement.entity';
import { DEFAULT_ACHIEVEMENTS } from '../gamification/gamification.constants';
import { GamificationService } from '../gamification/gamification.service';
import { generateInviteCode } from '../workspaces/workspaces.service';
import { AppException } from '../../common/exceptions/app.exception';
import { assertWorkspaceMember } from '../../common/utils/workspace-access.util';
import { BackupPayload } from './backup.types';

const BACKUP_VERSION = 1;

/// "Sao lưu & khôi phục" — full offline snapshot of one workspace's data,
/// meant to be exported to a file the user keeps themselves (Drive/Zalo/
/// email — the same share-sheet pattern as Excel export) and restored back
/// in later. Deliberately scoped to what reconstructs a *working ledger*:
/// vaults, categories, customers, transactions + their entries, and each
/// vault/debt balance exactly as it was. Budgets and recurring-transaction
/// templates are NOT included (a smaller, genuinely optional layer on top —
/// out of scope to keep this bounded); members/roles are not restorable
/// either (the restoring user becomes the sole owner of a fresh workspace,
/// matching how workspace deletion/creation already work).
@Injectable()
export class BackupService {
  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
    private readonly gamificationService: GamificationService,
  ) {}

  async exportBackup(workspaceId: string, userId: string): Promise<BackupPayload> {
    await assertWorkspaceMember(this.dataSource, workspaceId, userId);

    const workspace = await this.dataSource.getRepository(Workspace).findOne({ where: { id: workspaceId } });
    if (!workspace) {
      throw new AppException('NOT_FOUND', 'Không tìm thấy workspace');
    }

    const vaults = await this.dataSource.getRepository(Vault).find({ where: { workspaceId } });
    const categories = await this.dataSource.getRepository(Category).find({ where: { workspaceId } });
    const customers = await this.dataSource.getRepository(Customer).find({ where: { workspaceId } });
    const transactions = await this.dataSource.getRepository(Transaction).find({ where: { workspaceId }, order: { createdAt: 'ASC' } });
    const entriesByTransaction = await this.loadEntries(transactions.map((t) => t.id));

    return {
      backup_version: BACKUP_VERSION,
      exported_at: new Date().toISOString(),
      workspace: { name: workspace.name, type: workspace.type },
      vaults: vaults.map((v) => ({ id: v.id, name: v.name, type: v.type, current_balance: v.currentBalance })),
      categories: categories.map((c) => ({ id: c.id, name: c.name, group_name: c.groupName, icon: c.icon })),
      customers: customers.map((c) => ({ id: c.id, name: c.name, phone: c.phone, debt_vault_id: c.debtVaultId })),
      transactions: transactions.map((t) => ({
        id: t.id,
        type: t.type,
        amount: t.amount,
        note: t.note,
        cost_amount: t.costAmount,
        status: t.status,
        created_at: t.createdAt.toISOString(),
        category_id: t.categoryId,
        entries: (entriesByTransaction.get(t.id) ?? []).map((e) => ({ vault_id: e.vaultId, side: e.side, amount: e.amount })),
      })),
    };
  }

  private async loadEntries(transactionIds: string[]): Promise<Map<string, TransactionEntry[]>> {
    const map = new Map<string, TransactionEntry[]>();
    if (transactionIds.length === 0) return map;
    const entries = await this.dataSource
      .createQueryBuilder(TransactionEntry, 'e')
      .where('e.transaction_id IN (:...ids)', { ids: transactionIds })
      .getMany();
    for (const entry of entries) {
      const list = map.get(entry.transactionId) ?? [];
      list.push(entry);
      map.set(entry.transactionId, list);
    }
    return map;
  }

  /// Always creates a brand-new workspace (never merges into an existing
  /// one — far safer than trying to reconcile IDs/duplicates) with the
  /// restoring user as its sole owner. IDs from the backup are remapped to
  /// fresh ones throughout; only `created_at` on transactions is preserved
  /// exactly (via a raw update after insert, since `@CreateDateColumn`
  /// always stamps "now" on insert regardless of what's assigned first).
  async restoreBackup(userId: string, payload: BackupPayload) {
    if (!payload || typeof payload !== 'object' || !payload.workspace?.name) {
      throw new AppException('VALIDATION_ERROR', 'File backup không hợp lệ');
    }

    const workspaceId = await this.dataSource.transaction(async (manager) => {
      const workspace = manager.create(Workspace, {
        ownerId: userId,
        name: `${payload.workspace.name} (khôi phục)`,
        type: payload.workspace.type === 'family' ? 'family' : 'shop',
        inviteCode: generateInviteCode(),
      });
      await manager.save(workspace);
      await manager.save(manager.create(WorkspaceMember, { workspaceId: workspace.id, userId, role: 'owner' }));

      const vaultIdMap = new Map<string, string>();
      for (const v of payload.vaults ?? []) {
        const vault = manager.create(Vault, { workspaceId: workspace.id, name: v.name, type: v.type, currentBalance: 0 });
        await manager.save(vault);
        vaultIdMap.set(v.id, vault.id);
      }

      const categoryIdMap = new Map<string, string>();
      for (const c of payload.categories ?? []) {
        const category = manager.create(Category, { workspaceId: workspace.id, name: c.name, groupName: c.group_name, icon: c.icon ?? null });
        await manager.save(category);
        categoryIdMap.set(c.id, category.id);
      }

      for (const cust of payload.customers ?? []) {
        const newDebtVaultId = vaultIdMap.get(cust.debt_vault_id);
        if (!newDebtVaultId) continue; // malformed backup row — skip rather than fail the whole restore
        await manager.save(
          manager.create(Customer, { workspaceId: workspace.id, name: cust.name, phone: cust.phone ?? null, debtVaultId: newDebtVaultId }),
        );
      }

      for (const t of payload.transactions ?? []) {
        const transaction = manager.create(Transaction, {
          workspaceId: workspace.id,
          type: t.type,
          categoryId: t.category_id ? (categoryIdMap.get(t.category_id) ?? null) : null,
          amount: t.amount,
          costAmount: t.cost_amount ?? null,
          note: t.note ?? null,
          status: t.status === 'voided' ? 'voided' : 'completed',
          createdBy: userId,
        });
        await manager.save(transaction);
        if (t.created_at) {
          await manager
            .createQueryBuilder()
            .update(Transaction)
            .set({ createdAt: new Date(t.created_at) })
            .where('id = :id', { id: transaction.id })
            .execute();
        }
        for (const e of t.entries ?? []) {
          const newVaultId = vaultIdMap.get(e.vault_id);
          if (!newVaultId) continue;
          await manager.save(manager.create(TransactionEntry, { transactionId: transaction.id, vaultId: newVaultId, side: e.side, amount: e.amount }));
        }
      }

      // Final balances come straight from the backup snapshot rather than
      // being re-derived from replayed entries — simpler and exact.
      for (const v of payload.vaults ?? []) {
        const newId = vaultIdMap.get(v.id);
        if (!newId) continue;
        await manager.update(Vault, { id: newId }, { currentBalance: v.current_balance });
      }

      const achievements = DEFAULT_ACHIEVEMENTS.map((a) =>
        manager.create(Achievement, { workspaceId: workspace.id, key: a.key, name: a.name, description: a.description }),
      );
      await manager.save(achievements);

      return workspace.id;
    });

    await this.gamificationService.unlockFounderAchievement(workspaceId, userId);
    return { id: workspaceId };
  }
}
