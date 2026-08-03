import { Injectable } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource, EntityManager, In } from 'typeorm';
import { Transaction } from './entities/transaction.entity';
import { TransactionEntry, EntrySide } from './entities/transaction-entry.entity';
import { Vault } from '../vaults/entities/vault.entity';
import { Customer } from '../customers/entities/customer.entity';
import { CreateTransactionDto } from './dto/create-transaction.dto';
import { ListTransactionsQueryDto } from './dto/list-transactions.query.dto';
import { AppException } from '../../common/exceptions/app.exception';
import { assertWorkspaceMember } from '../../common/utils/workspace-access.util';
import { VIRTUAL_VAULT_NAMES } from '../vaults/vaults.constants';
import { GamificationService } from '../gamification/gamification.service';
import { BudgetsService } from '../budgets/budgets.service';
import { NotificationsService } from '../notifications/notifications.service';
import { AuditService } from '../audit/audit.service';
import { EditTransactionDto } from './dto/edit-transaction.dto';
import { formatVndAmount } from '../../common/utils/format.util';

const TRANSACTION_TYPE_LABEL_VI: Record<string, string> = {
  income: 'Thu tiền',
  expense: 'Chi tiền',
  transfer: 'Chuyển quỹ',
  debt_increase: 'Bán nợ',
  debt_decrease: 'Thu nợ',
};

interface ResolvedLegs {
  toVault?: Vault | null;
  fromVault?: Vault | null;
  customer?: (Customer & { debtVault: Vault }) | null;
}

@Injectable()
export class TransactionsService {
  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
    private readonly gamificationService: GamificationService,
    private readonly budgetsService: BudgetsService,
    private readonly notificationsService: NotificationsService,
    private readonly auditService: AuditService,
  ) {}

  async create(userId: string, dto: CreateTransactionDto, notify = true, deviceToken?: string) {
    await assertWorkspaceMember(this.dataSource, dto.workspace_id, userId);

    const response = await this.dataSource.transaction(async (manager) => {
      const { toVault, fromVault, customer } = await this.resolveLegs(manager, dto);
      const revenueVault = await this.getVirtualVault(manager, dto.workspace_id, VIRTUAL_VAULT_NAMES.REVENUE);
      const expenseVault = await this.getVirtualVault(manager, dto.workspace_id, VIRTUAL_VAULT_NAMES.EXPENSE);

      const transaction = manager.create(Transaction, {
        workspaceId: dto.workspace_id,
        type: dto.type,
        categoryId: dto.category_id ?? null,
        amount: dto.amount,
        costAmount: dto.type === 'income' ? dto.cost_amount ?? null : null,
        note: dto.note ?? null,
        status: 'completed',
        createdBy: userId,
      });
      await manager.save(transaction);

      const legs: { vault: Vault; side: EntrySide }[] = [];

      switch (dto.type) {
        case 'income': {
          toVault!.currentBalance += dto.amount;
          await manager.save(toVault!);
          legs.push({ vault: toVault!, side: 'D' }, { vault: revenueVault, side: 'C' });
          break;
        }
        case 'expense': {
          this.assertSufficientBalance(fromVault!, dto.amount);
          fromVault!.currentBalance -= dto.amount;
          await manager.save(fromVault!);
          legs.push({ vault: expenseVault, side: 'D' }, { vault: fromVault!, side: 'C' });
          break;
        }
        case 'transfer': {
          this.assertSufficientBalance(fromVault!, dto.amount);
          fromVault!.currentBalance -= dto.amount;
          toVault!.currentBalance += dto.amount;
          await manager.save(fromVault!);
          await manager.save(toVault!);
          legs.push({ vault: toVault!, side: 'D' }, { vault: fromVault!, side: 'C' });
          break;
        }
        case 'debt_increase': {
          const debtVault = customer!.debtVault;
          debtVault.currentBalance += dto.amount;
          await manager.save(debtVault);
          legs.push({ vault: debtVault, side: 'D' }, { vault: revenueVault, side: 'C' });
          break;
        }
        case 'debt_decrease': {
          const debtVault = customer!.debtVault;
          this.assertSufficientBalance(debtVault, dto.amount);
          debtVault.currentBalance -= dto.amount;
          toVault!.currentBalance += dto.amount;
          await manager.save(debtVault);
          await manager.save(toVault!);
          legs.push({ vault: toVault!, side: 'D' }, { vault: debtVault, side: 'C' });
          break;
        }
      }

      const entryRows = legs.map((leg) =>
        manager.create(TransactionEntry, {
          transactionId: transaction.id,
          vaultId: leg.vault.id,
          side: leg.side,
          amount: dto.amount,
        }),
      );
      await manager.save(entryRows);

      return this.buildResponse(manager, transaction.id);
    });

    // Gamification (Mục 9) is best-effort and runs after the money-moving
    // transaction has already committed — its own award writes are a
    // separate, smaller transaction inside GamificationService, so a
    // gamification hiccup never rolls back or blocks the real transaction.
    await this.gamificationService.awardXp(dto.workspace_id, userId, 'transaction_create');
    if (dto.source === 'voice') {
      await this.gamificationService.awardXp(dto.workspace_id, userId, 'voice_input');
    }
    if (dto.type === 'debt_decrease') {
      await this.gamificationService.awardXp(dto.workspace_id, userId, 'debt_decrease');
    }

    // Push notifications (Mục — "Thông báo đẩy") are best-effort, same
    // after-commit pattern as gamification above: never block or fail the
    // actual money-moving transaction over a notification hiccup. Skipped
    // when called from `edit()` (`notify = false`) — that path sends its
    // own single "Đã sửa giao dịch" notification instead of this plus a
    // separate void notification, which would read as two unrelated events
    // for what the user experiences as one action.
    if (notify) {
      try {
        await this.notificationsService.notifyWorkspace(dto.workspace_id, {
          title: TRANSACTION_TYPE_LABEL_VI[dto.type] ?? 'Giao dịch mới',
          body: `${formatVndAmount(dto.amount)}đ${dto.note ? ' • ' + dto.note : ''}`,
          excludeToken: deviceToken,
          data: { type: 'transaction_created', workspace_id: dto.workspace_id },
        });
        if (dto.type === 'expense') {
          const crossed = await this.budgetsService.checkJustCrossedLimit(dto.workspace_id, dto.category_id ?? null, dto.amount);
          for (const budget of crossed) {
            await this.notificationsService.notifyWorkspace(dto.workspace_id, {
              title: 'Vượt ngân sách!',
              body: `${budget.categoryName ?? 'Tổng chi tiêu'} đã chi ${formatVndAmount(budget.spent)}đ / ${formatVndAmount(budget.limitAmount)}đ hạn mức tháng này`,
              data: { type: 'budget_over_limit', workspace_id: dto.workspace_id },
            });
          }
        }
      } catch {
        // best-effort — see comment above
      }
    }

    return response;
  }

  /// Never a hard delete — flips `status` to `'voided'` and posts mirrored
  /// reversal entries (see `toTransactionDto`'s doc comment), keeping the
  /// full audit trail in the ledger itself. `reason` is optional free text,
  /// recorded only on the audit log entry, not on the transaction row.
  async void(transactionId: string, userId: string, reason?: string, notify = true, deviceToken?: string) {
    // Read outside the mutating transaction — purely for the audit log's
    // "before" snapshot, so a failure here can never affect the real void.
    const before = await this.buildResponse(this.dataSource.manager, transactionId).catch(() => null);

    const { dto, workspaceId } = await this.dataSource.transaction(async (manager) => {
      const transaction = await manager.findOne(Transaction, { where: { id: transactionId } });
      if (!transaction) {
        throw new AppException('NOT_FOUND', 'Không tìm thấy giao dịch');
      }
      const role = await assertWorkspaceMember(this.dataSource, transaction.workspaceId, userId);
      // Mục — "cài đặt phân quyền từng người": voiding/editing can rewrite
      // what a shift actually looked like, so it's restricted to
      // owner/manager. Deliberately NOT restricting transaction *creation*
      // itself — every member (including the pre-existing default
      // `'member'` role everyone already had before this permission system
      // existed) keeps being able to record sales/expenses exactly as
      // before.
      if (role === 'cashier' || role === 'member') {
        throw new AppException('FORBIDDEN', 'Chỉ chủ sở hữu hoặc quản lý mới có thể sửa/xoá giao dịch');
      }
      if (transaction.status !== 'completed') {
        throw new AppException('CONFLICT', 'Giao dịch đã bị hủy trước đó');
      }

      const originalEntries = await manager.find(TransactionEntry, { where: { transactionId } });
      const reversalRows: TransactionEntry[] = [];

      for (const entry of originalEntries) {
        const vault = await manager.findOne(Vault, { where: { id: entry.vaultId } });
        if (!vault) continue;

        // Virtual vaults (revenue/expense) are never balance-tracked — only
        // real vaults (cash/bank/ewallet/debt_customer/owner_wallet) get
        // their current_balance mirrored back.
        if (vault.type !== 'virtual') {
          vault.currentBalance += entry.side === 'D' ? -entry.amount : entry.amount;
          await manager.save(vault);
        }

        reversalRows.push(
          manager.create(TransactionEntry, {
            transactionId,
            vaultId: entry.vaultId,
            side: entry.side === 'D' ? 'C' : 'D',
            amount: entry.amount,
          }),
        );
      }
      await manager.save(reversalRows);

      transaction.status = 'voided';
      await manager.save(transaction);

      return { dto: await this.buildResponse(manager, transactionId), workspaceId: transaction.workspaceId };
    });

    await this.auditService.record(workspaceId, userId, 'transaction_void', 'transaction', transactionId, before, null, reason);

    // Best-effort, same pattern as create()'s — see its doc comment for why
    // `notify` is skipped when this is called from within `edit()`.
    if (notify) {
      try {
        await this.notificationsService.notifyWorkspace(workspaceId, {
          title: 'Đã hủy giao dịch',
          body: `${formatVndAmount(dto.amount)}đ${before?.note ? ' • ' + before.note : ''}${reason ? ' • Lý do: ' + reason : ''}`,
          excludeToken: deviceToken,
          data: { type: 'transaction_voided', workspace_id: workspaceId },
        });
      } catch {
        // best-effort — see comment above
      }
    }

    return dto;
  }

  /// "Xóa vĩnh viễn" — unlike `void`, actually removes the row (and its
  /// entries, cascade) instead of leaving a reversed-but-visible history
  /// entry. Deliberately a separate action from `void`, not a required
  /// first step: a `'completed'` transaction gets its vault balances
  /// reversed here (same math as `void`'s reversal, just applied directly
  /// instead of via a mirrored entry) before the row disappears; a
  /// `'voided'` transaction's balance effect is already net zero (the
  /// original + its reversal entries), so deleting it just removes the
  /// historical record with no balance math needed. Loses the audit trail
  /// for this specific transaction going forward — the deletion itself is
  /// still recorded in the audit log.
  async remove(transactionId: string, userId: string) {
    const before = await this.buildResponse(this.dataSource.manager, transactionId).catch(() => null);

    const workspaceId = await this.dataSource.transaction(async (manager) => {
      const transaction = await manager.findOne(Transaction, { where: { id: transactionId } });
      if (!transaction) {
        throw new AppException('NOT_FOUND', 'Không tìm thấy giao dịch');
      }
      const role = await assertWorkspaceMember(this.dataSource, transaction.workspaceId, userId);
      if (role === 'cashier' || role === 'member') {
        throw new AppException('FORBIDDEN', 'Chỉ chủ sở hữu hoặc quản lý mới có thể xoá giao dịch');
      }

      if (transaction.status === 'completed') {
        const entries = await manager.find(TransactionEntry, { where: { transactionId } });
        for (const entry of entries) {
          const vault = await manager.findOne(Vault, { where: { id: entry.vaultId } });
          if (!vault || vault.type === 'virtual') continue;
          vault.currentBalance += entry.side === 'D' ? -entry.amount : entry.amount;
          await manager.save(vault);
        }
      }

      await manager.delete(Transaction, { id: transactionId });
      return transaction.workspaceId;
    });

    await this.auditService.record(workspaceId, userId, 'transaction_delete', 'transaction', transactionId, before, null);
    return { success: true };
  }

  /// "Sửa giao dịch" (Mục — never mutates the original row): voids the
  /// original transaction (same reversal logic as a manual void, same audit
  /// trail) and creates a brand-new one with the edited values, so the
  /// ledger always shows exactly what changed and when rather than
  /// overwriting history. Both the void and the create get their own
  /// entries in `transactions`/`transaction_entries` — this is deliberately
  /// two ledger events, not one.
  async edit(transactionId: string, userId: string, dto: EditTransactionDto, deviceToken?: string) {
    const original = await this.dataSource.getRepository(Transaction).findOne({ where: { id: transactionId } });
    if (!original) {
      throw new AppException('NOT_FOUND', 'Không tìm thấy giao dịch');
    }
    await assertWorkspaceMember(this.dataSource, original.workspaceId, userId);
    if (original.status !== 'completed') {
      throw new AppException('CONFLICT', 'Giao dịch đã bị hủy, không thể sửa');
    }

    await this.void(transactionId, userId, dto.reason ?? 'Sửa giao dịch', false);

    const created = await this.create(
      userId,
      {
        workspace_id: original.workspaceId,
        type: dto.type,
        amount: dto.amount,
        category_id: dto.category_id,
        from_vault_id: dto.from_vault_id,
        to_vault_id: dto.to_vault_id,
        customer_id: dto.customer_id,
        note: dto.note,
        cost_amount: dto.cost_amount,
        source: 'manual',
      },
      false,
    );

    // A second, more specific audit entry linking old → new (the void()
    // call above already recorded its own "transaction_void" entry against
    // the original id) — this one is keyed to the *new* transaction so a
    // "Lịch sử" lookup on the new row shows what it replaced.
    await this.auditService.record(original.workspaceId, userId, 'transaction_edit', 'transaction', created.id, null, created, dto.reason);

    // One notification for the whole edit — see create()/void()'s doc
    // comments for why their own notifications are suppressed here.
    try {
      await this.notificationsService.notifyWorkspace(original.workspaceId, {
        title: 'Đã sửa giao dịch',
        body: `${formatVndAmount(created.amount)}đ${created.note ? ' • ' + created.note : ''}`,
        excludeToken: deviceToken,
        data: { type: 'transaction_edited', workspace_id: original.workspaceId },
      });
    } catch {
      // best-effort — see create()'s doc comment
    }

    return { voided_transaction_id: transactionId, transaction: created };
  }

  async list(userId: string, query: ListTransactionsQueryDto) {
    await assertWorkspaceMember(this.dataSource, query.workspace_id, userId);

    const page = query.page ?? 1;
    const limit = query.limit ?? 20;

    const qb = this.dataSource
      .getRepository(Transaction)
      .createQueryBuilder('t')
      .leftJoinAndSelect('t.category', 'category')
      .leftJoinAndSelect('t.createdByUser', 'createdByUser')
      .where('t.workspaceId = :workspaceId', { workspaceId: query.workspace_id })
      .orderBy('t.createdAt', 'DESC');

    if (query.type) {
      qb.andWhere('t.type = :type', { type: query.type });
    }

    if (query.from_date) {
      qb.andWhere('t.createdAt >= :fromDate', { fromDate: query.from_date });
    }

    if (query.to_date) {
      qb.andWhere('t.createdAt <= :toDate', { toDate: query.to_date });
    }

    if (query.vault_id) {
      const matches = await this.dataSource
        .getRepository(TransactionEntry)
        .createQueryBuilder('e')
        .select('DISTINCT e.transactionId', 'transactionId')
        .where('e.vaultId = :vaultId', { vaultId: query.vault_id })
        .getRawMany<{ transactionId: string }>();
      const ids = matches.map((m) => m.transactionId);
      if (ids.length === 0) {
        return { data: [], pagination: { page, total_pages: 1 } };
      }
      qb.andWhere('t.id IN (:...ids)', { ids });
    }

    const total = await qb.getCount();
    const rows = await qb
      .skip((page - 1) * limit)
      .take(limit)
      .getMany();

    const transactionIds = rows.map((r) => r.id);
    const entries = transactionIds.length
      ? await this.dataSource
          .getRepository(TransactionEntry)
          .find({ where: { transactionId: In(transactionIds) }, relations: { vault: true } })
      : [];
    const entriesByTransaction = new Map<string, TransactionEntry[]>();
    for (const entry of entries) {
      const list = entriesByTransaction.get(entry.transactionId) ?? [];
      list.push(entry);
      entriesByTransaction.set(entry.transactionId, list);
    }

    const data = await Promise.all(
      rows.map((t) => this.toTransactionDto(this.dataSource.manager, t, entriesByTransaction.get(t.id) ?? [])),
    );
    return { data, pagination: { page, total_pages: Math.max(1, Math.ceil(total / limit)) } };
  }

  // --- helpers -------------------------------------------------------

  private async resolveLegs(manager: EntityManager, dto: CreateTransactionDto): Promise<ResolvedLegs> {
    const result: ResolvedLegs = {};

    if (dto.to_vault_id) {
      result.toVault = await this.loadVaultInWorkspace(manager, dto.to_vault_id, dto.workspace_id);
    }
    if (dto.from_vault_id) {
      result.fromVault = await this.loadVaultInWorkspace(manager, dto.from_vault_id, dto.workspace_id);
    }
    if (dto.customer_id) {
      const customer = await manager.findOne(Customer, {
        where: { id: dto.customer_id, workspaceId: dto.workspace_id },
        relations: { debtVault: true },
      });
      if (!customer) {
        throw new AppException('NOT_FOUND', 'Không tìm thấy khách hàng trong workspace này');
      }
      result.customer = customer as Customer & { debtVault: Vault };
    }
    return result;
  }

  private async loadVaultInWorkspace(manager: EntityManager, vaultId: string, workspaceId: string): Promise<Vault> {
    const vault = await manager.findOne(Vault, { where: { id: vaultId } });
    if (!vault) {
      throw new AppException('NOT_FOUND', 'Không tìm thấy quỹ');
    }
    if (vault.workspaceId !== workspaceId) {
      throw new AppException('VAULT_NOT_IN_WORKSPACE', 'Quỹ không thuộc workspace này');
    }
    return vault;
  }

  private async getVirtualVault(manager: EntityManager, workspaceId: string, name: string): Promise<Vault> {
    const vault = await manager.findOne(Vault, { where: { workspaceId, type: 'virtual', name } });
    if (!vault) {
      throw new AppException('INTERNAL_ERROR', `Thiếu vault ảo "${name}" cho workspace, hãy kiểm tra lại dữ liệu`);
    }
    return vault;
  }

  private assertSufficientBalance(vault: Vault, amount: number): void {
    if (vault.currentBalance < amount) {
      throw new AppException('INSUFFICIENT_BALANCE', 'Số dư quỹ không đủ để thực hiện giao dịch này');
    }
  }

  private async buildResponse(manager: EntityManager, transactionId: string) {
    const transaction = await manager.findOne(Transaction, {
      where: { id: transactionId },
      relations: { category: true, createdByUser: true },
    });
    if (!transaction) {
      throw new AppException('NOT_FOUND', 'Không tìm thấy giao dịch');
    }
    const entries = await manager.find(TransactionEntry, {
      where: { transactionId },
      relations: { vault: true },
    });
    return this.toTransactionDto(manager, transaction, entries);
  }

  /**
   * Derives the human-facing from_vault/to_vault fields from the ledger
   * entries: the "D & non-virtual" entry is the destination, the
   * "C & non-virtual" entry is the source (see class doc on
   * TransactionEntry for why virtual vaults are excluded). For a voided
   * transaction there are 4 entries (2 original + 2 mirrored reversal); the
   * reversal of a D entry is posted as C (and vice versa) on the *same*
   * vault, so this filter still isolates a single matching entry per side
   * for income/expense/debt_increase. For transfer/debt_decrease — where
   * both legs are real vaults — the two entries created first (before any
   * void) are used, since `manager.find` returns rows in insertion order
   * for this append-only table.
   */
  private async toTransactionDto(manager: EntityManager, transaction: Transaction, entries: TransactionEntry[]) {
    const relevant = entries.length > 2 ? entries.slice(0, 2) : entries;
    const toEntry = relevant.find((e) => e.side === 'D' && e.vault?.type !== 'virtual');
    const fromEntry = relevant.find((e) => e.side === 'C' && e.vault?.type !== 'virtual');

    // debt_increase/debt_decrease post to the customer's debt vault as a
    // regular (non-virtual) leg, so it already surfaces as from_vault/
    // to_vault above — this just also resolves *which customer* that debt
    // vault belongs to, so an edit form has something to pre-fill.
    let customer: { id: string; name: string } | null = null;
    if (transaction.type === 'debt_increase' || transaction.type === 'debt_decrease') {
      const debtVaultId = (toEntry?.vault?.type === 'debt_customer' ? toEntry.vault.id : fromEntry?.vault?.type === 'debt_customer' ? fromEntry.vault.id : null);
      if (debtVaultId) {
        const row = await manager.findOne(Customer, { where: { debtVaultId } });
        if (row) customer = { id: row.id, name: row.name };
      }
    }

    return {
      id: transaction.id,
      type: transaction.type,
      amount: transaction.amount,
      cost_amount: transaction.costAmount,
      // Only meaningful (non-null) for an income transaction that actually
      // recorded a cost — see Transaction.costAmount doc comment.
      profit: transaction.type === 'income' && transaction.costAmount != null ? transaction.amount - transaction.costAmount : null,
      note: transaction.note,
      status: transaction.status,
      category: transaction.category ? { id: transaction.category.id, name: transaction.category.name } : null,
      from_vault: fromEntry?.vault ? { id: fromEntry.vault.id, name: fromEntry.vault.name, type: fromEntry.vault.type } : null,
      to_vault: toEntry?.vault ? { id: toEntry.vault.id, name: toEntry.vault.name, type: toEntry.vault.type } : null,
      customer,
      created_by: transaction.createdByUser ? { id: transaction.createdByUser.id, name: transaction.createdByUser.fullName } : null,
      created_at: transaction.createdAt,
      entries: entries.map((e) => ({ id: e.id, vault_id: e.vaultId, side: e.side, amount: e.amount })),
    };
  }
}
