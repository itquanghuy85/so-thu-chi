import { Injectable } from '@nestjs/common';
import { InjectDataSource, InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { DailyClosing, DailyClosingEntry } from './entities/daily-closing.entity';
import { CreateDailyClosingDto } from './dto/create-daily-closing.dto';
import { Vault } from '../vaults/entities/vault.entity';
import { VaultsService } from '../vaults/vaults.service';
import { AuditService } from '../audit/audit.service';
import { AppException } from '../../common/exceptions/app.exception';

function todayDateString(): string {
  const now = new Date();
  const y = now.getFullYear();
  const m = String(now.getMonth() + 1).padStart(2, '0');
  const d = String(now.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

@Injectable()
export class DailyClosingsService {
  constructor(
    @InjectRepository(DailyClosing) private readonly dailyClosingsRepository: Repository<DailyClosing>,
    @InjectDataSource() private readonly dataSource: DataSource,
    private readonly vaultsService: VaultsService,
    private readonly auditService: AuditService,
  ) {}

  async list(workspaceId: string) {
    const rows = await this.dailyClosingsRepository.find({
      where: { workspaceId },
      relations: { closedByUser: true },
      order: { closingDate: 'DESC' },
    });
    return rows.map((r) => this.toDto(r));
  }

  async todayStatus(workspaceId: string) {
    const row = await this.dailyClosingsRepository.findOne({
      where: { workspaceId, closingDate: todayDateString() },
      relations: { closedByUser: true },
    });
    return { closed: !!row, closing: row ? this.toDto(row) : null };
  }

  /// Reuses `VaultsService.reconcile` per vault for the actual
  /// balance-adjustment logic (same "count the drawer, correct the books"
  /// action already exposed as the standalone "Kiểm kê" quick action) —
  /// this just bundles a whole day's worth of them into one historical
  /// record and enforces the once-per-day rule.
  async close(workspaceId: string, userId: string, dto: CreateDailyClosingDto) {
    const closingDate = todayDateString();
    const existing = await this.dailyClosingsRepository.findOne({ where: { workspaceId, closingDate } });
    if (existing) {
      throw new AppException('CONFLICT', 'Hôm nay đã chốt sổ rồi');
    }

    const entries: DailyClosingEntry[] = [];
    let totalVariance = 0;
    for (const e of dto.entries) {
      const vault = await this.dataSource.getRepository(Vault).findOne({ where: { id: e.vault_id, workspaceId } });
      if (!vault) {
        throw new AppException('NOT_FOUND', 'Không tìm thấy quỹ trong workspace này');
      }
      const bookBalanceBefore = vault.currentBalance;
      const { difference } = await this.vaultsService.reconcile(vault.id, userId, {
        actual_balance: e.actual_balance,
        reason: 'Chốt sổ cuối ngày',
      });
      entries.push({
        vault_id: vault.id,
        name: vault.name,
        book_balance: bookBalanceBefore,
        actual_balance: e.actual_balance,
        variance: difference,
      });
      totalVariance += difference;
    }

    const closing = this.dailyClosingsRepository.create({
      workspaceId,
      closedBy: userId,
      closingDate,
      entries,
      totalVariance,
      note: dto.note ?? null,
    });
    await this.dailyClosingsRepository.save(closing);

    await this.auditService.record(workspaceId, userId, 'daily_closing', 'daily_closing', closing.id, null, { entries, total_variance: totalVariance }, dto.note);

    return this.toDto(closing);
  }

  private toDto(row: DailyClosing) {
    return {
      id: row.id,
      closing_date: row.closingDate,
      entries: row.entries,
      total_variance: row.totalVariance,
      note: row.note,
      closed_by_name: row.closedByUser?.fullName ?? '',
      created_at: row.createdAt,
    };
  }
}
