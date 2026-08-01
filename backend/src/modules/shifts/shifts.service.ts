import { Injectable } from '@nestjs/common';
import { InjectDataSource, InjectRepository } from '@nestjs/typeorm';
import { DataSource, IsNull, Not, Repository } from 'typeorm';
import { Shift, VaultSnapshotEntry } from './entities/shift.entity';
import { Vault } from '../vaults/entities/vault.entity';
import { Transaction } from '../transactions/entities/transaction.entity';
import { OpenShiftDto } from './dto/open-shift.dto';
import { CloseShiftDto } from './dto/close-shift.dto';
import { AppException } from '../../common/exceptions/app.exception';

@Injectable()
export class ShiftsService {
  constructor(
    @InjectRepository(Shift) private readonly shiftsRepository: Repository<Shift>,
    @InjectDataSource() private readonly dataSource: DataSource,
  ) {}

  async open(workspaceId: string, userId: string, dto: OpenShiftDto) {
    const existingOpen = await this.shiftsRepository.findOne({ where: { workspaceId, userId, closedAt: IsNull() } });
    if (existingOpen) {
      throw new AppException('CONFLICT', 'Bạn đang có một ca làm việc chưa kết thúc');
    }

    const shift = this.shiftsRepository.create({
      workspaceId,
      userId,
      openingSnapshot: await this.snapshotVaults(workspaceId),
      closingSnapshot: null,
      closedAt: null,
      note: dto.note ?? null,
    });
    await this.shiftsRepository.save(shift);
    return this.toDto(shift, await this.summary(workspaceId, shift.openedAt, new Date()));
  }

  async close(workspaceId: string, userId: string, shiftId: string, dto: CloseShiftDto) {
    const shift = await this.shiftsRepository.findOne({ where: { id: shiftId, workspaceId } });
    if (!shift) {
      throw new AppException('NOT_FOUND', 'Không tìm thấy ca làm việc');
    }
    if (shift.userId !== userId) {
      throw new AppException('FORBIDDEN', 'Bạn chỉ có thể kết thúc ca làm việc của chính mình');
    }
    if (shift.closedAt) {
      throw new AppException('CONFLICT', 'Ca làm việc này đã kết thúc trước đó');
    }

    shift.closingSnapshot = await this.snapshotVaults(workspaceId);
    shift.closedAt = new Date();
    if (dto.note) shift.note = dto.note;
    await this.shiftsRepository.save(shift);

    return this.toDto(shift, await this.summary(workspaceId, shift.openedAt, shift.closedAt));
  }

  async list(workspaceId: string) {
    const shifts = await this.shiftsRepository.find({
      where: { workspaceId },
      relations: { user: true },
      order: { openedAt: 'DESC' },
    });
    return Promise.all(
      shifts.map(async (s) => ({
        ...this.toDto(s, await this.summary(workspaceId, s.openedAt, s.closedAt ?? new Date())),
        user_name: s.user?.fullName ?? '',
      })),
    );
  }

  async getCurrentOpen(workspaceId: string, userId: string) {
    const shift = await this.shiftsRepository.findOne({ where: { workspaceId, userId, closedAt: IsNull() } });
    if (!shift) return null;
    return this.toDto(shift, await this.summary(workspaceId, shift.openedAt, new Date()));
  }

  private async snapshotVaults(workspaceId: string): Promise<VaultSnapshotEntry[]> {
    const vaults = await this.dataSource.getRepository(Vault).find({ where: { workspaceId, type: Not('virtual') } });
    return vaults.map((v) => ({ vault_id: v.id, name: v.name, balance: v.currentBalance }));
  }

  private async summary(workspaceId: string, from: Date, to: Date) {
    const qb = this.dataSource
      .getRepository(Transaction)
      .createQueryBuilder('t')
      .select('t.type', 'type')
      .addSelect('COALESCE(SUM(t.amount), 0)', 'sum')
      .where('t.workspaceId = :workspaceId', { workspaceId })
      .andWhere('t.status = :status', { status: 'completed' })
      .andWhere('t.createdAt >= :from', { from })
      .andWhere('t.createdAt < :to', { to })
      .groupBy('t.type');
    const rows = await qb.getRawMany<{ type: string; sum: string }>();
    const byType = new Map(rows.map((r) => [r.type, parseInt(r.sum, 10) || 0]));
    return {
      income: byType.get('income') ?? 0,
      expense: byType.get('expense') ?? 0,
    };
  }

  private toDto(shift: Shift, summary: { income: number; expense: number }) {
    return {
      id: shift.id,
      opened_at: shift.openedAt,
      closed_at: shift.closedAt,
      opening_snapshot: shift.openingSnapshot,
      closing_snapshot: shift.closingSnapshot,
      note: shift.note,
      income_during_shift: summary.income,
      expense_during_shift: summary.expense,
    };
  }
}
