import { Injectable } from '@nestjs/common';
import { InjectDataSource, InjectRepository } from '@nestjs/typeorm';
import { DataSource, Not, Repository } from 'typeorm';
import { Vault } from './entities/vault.entity';
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
}
