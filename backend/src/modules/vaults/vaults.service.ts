import { Injectable } from '@nestjs/common';
import { InjectDataSource, InjectRepository } from '@nestjs/typeorm';
import { DataSource, Not, Repository } from 'typeorm';
import { Vault } from './entities/vault.entity';
import { TransactionEntry } from '../transactions/entities/transaction-entry.entity';
import { CreateVaultDto } from './dto/create-vault.dto';
import { ReconcileVaultDto } from './dto/reconcile-vault.dto';
import { AppException } from '../../common/exceptions/app.exception';
import { assertWorkspaceMember } from '../../common/utils/workspace-access.util';
import { GamificationService } from '../gamification/gamification.service';

@Injectable()
export class VaultsService {
  constructor(
    @InjectRepository(Vault) private readonly vaultsRepository: Repository<Vault>,
    @InjectDataSource() private readonly dataSource: DataSource,
    private readonly gamificationService: GamificationService,
  ) {}

  async listForWorkspace(workspaceId: string) {
    const vaults = await this.vaultsRepository.find({
      where: { workspaceId, type: Not('virtual') },
      order: { createdAt: 'ASC' },
    });
    return vaults.map((v) => ({ id: v.id, name: v.name, type: v.type, current_balance: v.currentBalance }));
  }

  async create(workspaceId: string, dto: CreateVaultDto) {
    const vault = this.vaultsRepository.create({
      workspaceId,
      name: dto.name,
      type: dto.type,
      currentBalance: dto.initial_balance ?? 0,
    });
    await this.vaultsRepository.save(vault);
    return { id: vault.id, name: vault.name, type: vault.type, current_balance: vault.currentBalance };
  }

  async reconcile(vaultId: string, userId: string, dto: ReconcileVaultDto) {
    const vault = await this.vaultsRepository.findOne({ where: { id: vaultId } });
    if (!vault) {
      throw new AppException('NOT_FOUND', 'Không tìm thấy quỹ');
    }
    await assertWorkspaceMember(this.dataSource, vault.workspaceId, userId);

    const difference = dto.actual_balance - vault.currentBalance;
    vault.currentBalance = dto.actual_balance;
    await this.vaultsRepository.save(vault);

    // Gamification (Mục 9 "Kiểm kê khớp: +30 XP") — only when the count
    // matched the books exactly, same as the "Khớp với sổ sách" copy shown
    // client-side in the reconcile sheet.
    if (difference === 0) {
      await this.gamificationService.awardXp(vault.workspaceId, userId, 'reconcile_match');
      await this.gamificationService.unlockReconcileAchievementIfFirst(vault.workspaceId, userId);
    }

    return {
      vault: { id: vault.id, name: vault.name, type: vault.type, current_balance: vault.currentBalance },
      difference,
    };
  }

  /// "Xóa túi tiền" — blocked if it has ever appeared in a transaction
  /// (deleting it would silently cascade-delete those transaction_entries
  /// rows too, per `TransactionEntry.vault`'s `onDelete: 'CASCADE'`, leaving
  /// the transaction itself with a missing leg). Not deletable this way at
  /// all: the two `'virtual'` bookkeeping vaults every workspace has.
  async remove(vaultId: string, userId: string) {
    const vault = await this.vaultsRepository.findOne({ where: { id: vaultId } });
    if (!vault) {
      throw new AppException('NOT_FOUND', 'Không tìm thấy quỹ');
    }
    await assertWorkspaceMember(this.dataSource, vault.workspaceId, userId);
    if (vault.type === 'virtual') {
      throw new AppException('VALIDATION_ERROR', 'Không thể xoá quỹ hệ thống');
    }
    const usageCount = await this.dataSource.getRepository(TransactionEntry).count({ where: { vaultId } });
    if (usageCount > 0) {
      throw new AppException(
        'CONFLICT',
        `Không thể xoá vì túi tiền đã có ${usageCount} giao dịch — hãy đảm bảo không còn giao dịch nào dùng túi này trước`,
      );
    }
    await this.vaultsRepository.delete({ id: vaultId });
    return { success: true };
  }
}
