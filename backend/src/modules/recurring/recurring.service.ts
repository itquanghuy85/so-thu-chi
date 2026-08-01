import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { LessThanOrEqual, Repository } from 'typeorm';
import { RecurringTransaction, RecurringFrequency } from './entities/recurring-transaction.entity';
import { CreateRecurringDto } from './dto/create-recurring.dto';
import { UpdateRecurringDto } from './dto/update-recurring.dto';
import { TransactionsService } from '../transactions/transactions.service';
import { NotificationsService } from '../notifications/notifications.service';
import { AppException } from '../../common/exceptions/app.exception';

const MAX_CATCH_UP_RUNS = 24; // safety cap if the app hasn't been opened in a very long time

@Injectable()
export class RecurringService {
  constructor(
    @InjectRepository(RecurringTransaction) private readonly recurringRepository: Repository<RecurringTransaction>,
    private readonly transactionsService: TransactionsService,
    private readonly notificationsService: NotificationsService,
  ) {}

  async create(userId: string, workspaceId: string, dto: CreateRecurringDto) {
    const recurring = this.recurringRepository.create({
      workspaceId,
      type: dto.type,
      amount: dto.amount,
      categoryId: dto.category_id ?? null,
      fromVaultId: dto.from_vault_id ?? null,
      toVaultId: dto.to_vault_id ?? null,
      customerId: dto.customer_id ?? null,
      note: dto.note ?? null,
      frequency: dto.frequency,
      nextRunDate: new Date(dto.start_date),
      active: true,
      createdBy: userId,
    });
    await this.recurringRepository.save(recurring);
    return this.getOne(workspaceId, recurring.id);
  }

  async list(workspaceId: string) {
    const rows = await this.recurringRepository.find({
      where: { workspaceId },
      relations: { category: true, fromVault: true, toVault: true, customer: true },
      order: { nextRunDate: 'ASC' },
    });
    return rows.map((r) => this.toDto(r));
  }

  async update(workspaceId: string, id: string, dto: UpdateRecurringDto) {
    const recurring = await this.recurringRepository.findOne({ where: { id, workspaceId } });
    if (!recurring) {
      throw new AppException('NOT_FOUND', 'Không tìm thấy giao dịch định kỳ');
    }
    if (dto.active !== undefined) recurring.active = dto.active;
    await this.recurringRepository.save(recurring);
    return this.getOne(workspaceId, recurring.id);
  }

  /// Re-fetches with relations loaded — see the identical note on
  /// BudgetsService.getOne for why `.save()` alone isn't enough.
  private async getOne(workspaceId: string, id: string) {
    const recurring = await this.recurringRepository.findOne({
      where: { id, workspaceId },
      relations: { category: true, fromVault: true, toVault: true, customer: true },
    });
    if (!recurring) {
      throw new AppException('NOT_FOUND', 'Không tìm thấy giao dịch định kỳ');
    }
    return this.toDto(recurring);
  }

  async remove(workspaceId: string, id: string) {
    const recurring = await this.recurringRepository.findOne({ where: { id, workspaceId } });
    if (!recurring) {
      throw new AppException('NOT_FOUND', 'Không tìm thấy giao dịch định kỳ');
    }
    await this.recurringRepository.delete({ id, workspaceId });
    return { success: true };
  }

  /// Materializes every occurrence whose `nextRunDate` has arrived, calling
  /// the exact same `TransactionsService.create` a manual entry would use
  /// (so balances/gamification/audit trail all behave identically to a
  /// real user creating that transaction) — attributed to whoever originally
  /// set up the recurring entry (`createdBy`), not whoever happens to be
  /// the one to trigger this call.
  async runDue(workspaceId: string) {
    const due = await this.recurringRepository.find({
      where: { workspaceId, active: true, nextRunDate: LessThanOrEqual(new Date()) },
    });

    const createdTransactionIds: string[] = [];
    for (const recurring of due) {
      let runs = 0;
      while (recurring.nextRunDate <= new Date() && runs < MAX_CATCH_UP_RUNS) {
        try {
          const created = await this.transactionsService.create(recurring.createdBy, {
            workspace_id: workspaceId,
            type: recurring.type,
            amount: recurring.amount,
            category_id: recurring.categoryId ?? undefined,
            from_vault_id: recurring.fromVaultId ?? undefined,
            to_vault_id: recurring.toVaultId ?? undefined,
            customer_id: recurring.customerId ?? undefined,
            note: recurring.note ?? undefined,
            source: 'recurring',
          });
          createdTransactionIds.push(created.id);
        } catch (e) {
          // A genuinely broken recurring entry (e.g. its vault was deleted,
          // or insufficient balance for an expense) shouldn't jam every
          // future run — stop advancing it and surface the failure on the
          // list screen instead of silently retrying forever.
          recurring.active = false;
          break;
        }
        recurring.nextRunDate = advance(recurring.nextRunDate, recurring.frequency);
        runs++;
      }
      await this.recurringRepository.save(recurring);
    }

    if (createdTransactionIds.length > 0) {
      try {
        await this.notificationsService.notifyWorkspace(workspaceId, {
          title: 'Giao dịch định kỳ',
          body: `Đã tự động ghi ${createdTransactionIds.length} giao dịch định kỳ đến hạn`,
          data: { type: 'recurring_run', workspace_id: workspaceId },
        });
      } catch {
        // best-effort — see TransactionsService.create for the same pattern
      }
    }

    return { created_count: createdTransactionIds.length, transaction_ids: createdTransactionIds };
  }

  private toDto(r: RecurringTransaction) {
    return {
      id: r.id,
      type: r.type,
      amount: r.amount,
      note: r.note,
      frequency: r.frequency,
      next_run_date: r.nextRunDate,
      active: r.active,
      category: r.category ? { id: r.category.id, name: r.category.name } : null,
      from_vault: r.fromVault ? { id: r.fromVault.id, name: r.fromVault.name } : null,
      to_vault: r.toVault ? { id: r.toVault.id, name: r.toVault.name } : null,
      customer: r.customer ? { id: r.customer.id, name: r.customer.name } : null,
    };
  }
}

function advance(date: Date, frequency: RecurringFrequency): Date {
  const next = new Date(date);
  switch (frequency) {
    case 'daily':
      next.setDate(next.getDate() + 1);
      break;
    case 'weekly':
      next.setDate(next.getDate() + 7);
      break;
    case 'monthly':
      next.setMonth(next.getMonth() + 1);
      break;
  }
  return next;
}
