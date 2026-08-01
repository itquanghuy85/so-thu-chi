import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuditAction, AuditLog } from './entities/audit-log.entity';

@Injectable()
export class AuditService {
  constructor(@InjectRepository(AuditLog) private readonly auditRepository: Repository<AuditLog>) {}

  /// Best-effort — a logging failure must never break the mutation it's
  /// describing (same "never block the real action" pattern used for
  /// gamification/notifications elsewhere in this codebase).
  async record(
    workspaceId: string,
    userId: string,
    action: AuditAction,
    entityType: string,
    entityId: string,
    beforeData: unknown | null,
    afterData: unknown | null,
    note?: string | null,
  ): Promise<void> {
    try {
      const row = this.auditRepository.create({
        workspaceId,
        userId,
        action,
        entityType,
        entityId,
        beforeData: beforeData ?? null,
        afterData: afterData ?? null,
        note: note ?? null,
      });
      await this.auditRepository.save(row);
    } catch {
      // best-effort
    }
  }

  async list(workspaceId: string, filter: { entityType?: string; entityId?: string; page?: number; limit?: number }) {
    const page = filter.page ?? 1;
    const limit = filter.limit ?? 30;

    const qb = this.auditRepository
      .createQueryBuilder('a')
      .leftJoinAndSelect('a.user', 'user')
      .where('a.workspaceId = :workspaceId', { workspaceId })
      .orderBy('a.createdAt', 'DESC');

    if (filter.entityType) qb.andWhere('a.entityType = :entityType', { entityType: filter.entityType });
    if (filter.entityId) qb.andWhere('a.entityId = :entityId', { entityId: filter.entityId });

    const total = await qb.getCount();
    const rows = await qb
      .skip((page - 1) * limit)
      .take(limit)
      .getMany();

    return {
      data: rows.map((r) => ({
        id: r.id,
        action: r.action,
        entity_type: r.entityType,
        entity_id: r.entityId,
        before: r.beforeData,
        after: r.afterData,
        note: r.note,
        user_name: r.user?.fullName ?? '',
        created_at: r.createdAt,
      })),
      pagination: { page, total_pages: Math.max(1, Math.ceil(total / limit)) },
    };
  }
}
