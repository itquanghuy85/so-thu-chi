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
  ) {}

  async create(userId: string, dto: CreateTransactionDto) {
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

    return response;
  }

  async void(transactionId: string, userId: string) {
    return this.dataSource.transaction(async (manager) => {
      const transaction = await manager.findOne(Transaction, { where: { id: transactionId } });
      if (!transaction) {
        throw new AppException('NOT_FOUND', 'Không tìm thấy giao dịch');
      }
      await assertWorkspaceMember(this.dataSource, transaction.workspaceId, userId);
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

      return this.buildResponse(manager, transactionId);
    });
  }

  async list(userId: string, query: ListTransactionsQueryDto) {
    await assertWorkspaceMember(this.dataSource, query.workspace_id, userId);

    const page = query.page ?? 1;
    const limit = query.limit ?? 20;

    const qb = this.dataSource
      .getRepository(Transaction)
      .createQueryBuilder('t')
      .leftJoinAndSelect('t.category', 'category')
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

    const data = rows.map((t) => this.toTransactionDto(t, entriesByTransaction.get(t.id) ?? []));
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
      relations: { category: true },
    });
    if (!transaction) {
      throw new AppException('NOT_FOUND', 'Không tìm thấy giao dịch');
    }
    const entries = await manager.find(TransactionEntry, {
      where: { transactionId },
      relations: { vault: true },
    });
    return this.toTransactionDto(transaction, entries);
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
  private toTransactionDto(transaction: Transaction, entries: TransactionEntry[]) {
    const relevant = entries.length > 2 ? entries.slice(0, 2) : entries;
    const toEntry = relevant.find((e) => e.side === 'D' && e.vault?.type !== 'virtual');
    const fromEntry = relevant.find((e) => e.side === 'C' && e.vault?.type !== 'virtual');

    return {
      id: transaction.id,
      type: transaction.type,
      amount: transaction.amount,
      note: transaction.note,
      status: transaction.status,
      category: transaction.category ? { id: transaction.category.id, name: transaction.category.name } : null,
      from_vault: fromEntry?.vault ? { id: fromEntry.vault.id, name: fromEntry.vault.name, type: fromEntry.vault.type } : null,
      to_vault: toEntry?.vault ? { id: toEntry.vault.id, name: toEntry.vault.name, type: toEntry.vault.type } : null,
      created_at: transaction.createdAt,
      entries: entries.map((e) => ({ id: e.id, vault_id: e.vaultId, side: e.side, amount: e.amount })),
    };
  }
}
