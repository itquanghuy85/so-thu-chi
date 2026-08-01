import { Injectable } from '@nestjs/common';
import { InjectDataSource, InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { Workspace } from './entities/workspace.entity';
import { WorkspaceMember } from './entities/workspace-member.entity';
import { Vault } from '../vaults/entities/vault.entity';
import { User } from '../users/entities/user.entity';
import { VIRTUAL_VAULT_NAMES } from '../vaults/vaults.constants';
import { Category } from '../categories/entities/category.entity';
import { DEFAULT_CATEGORIES } from '../categories/categories.constants';
import { Achievement } from '../gamification/entities/achievement.entity';
import { DEFAULT_ACHIEVEMENTS } from '../gamification/gamification.constants';
import { GamificationService } from '../gamification/gamification.service';
import { CreateWorkspaceDto } from './dto/create-workspace.dto';
import { JoinWorkspaceDto } from './dto/join-workspace.dto';
import { AppException } from '../../common/exceptions/app.exception';

const INVITE_CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I — easy to read aloud

function generateInviteCode(): string {
  let code = '';
  for (let i = 0; i < 8; i++) {
    code += INVITE_CODE_ALPHABET[Math.floor(Math.random() * INVITE_CODE_ALPHABET.length)];
  }
  return code;
}

@Injectable()
export class WorkspacesService {
  constructor(
    @InjectRepository(Workspace) private readonly workspacesRepository: Repository<Workspace>,
    @InjectRepository(WorkspaceMember) private readonly membersRepository: Repository<WorkspaceMember>,
    @InjectDataSource() private readonly dataSource: DataSource,
    private readonly gamificationService: GamificationService,
  ) {}

  async listForUser(userId: string) {
    const memberships = await this.membersRepository.find({ where: { userId } });
    const results: {
      id: string;
      name: string;
      type: Workspace['type'];
      owner_id: string;
      member_count: number;
      role: WorkspaceMember['role'];
    }[] = [];
    for (const membership of memberships) {
      const workspace = await this.workspacesRepository.findOne({ where: { id: membership.workspaceId } });
      if (!workspace) continue;
      const memberCount = await this.membersRepository.count({ where: { workspaceId: workspace.id } });
      results.push({
        id: workspace.id,
        name: workspace.name,
        type: workspace.type,
        owner_id: workspace.ownerId,
        member_count: memberCount,
        role: membership.role,
      });
    }
    return results;
  }

  async create(userId: string, dto: CreateWorkspaceDto) {
    const response = await this.dataSource.transaction(async (manager) => {
      const workspace = manager.create(Workspace, {
        ownerId: userId,
        name: dto.name,
        type: dto.type,
        inviteCode: generateInviteCode(),
      });
      await manager.save(workspace);

      const member = manager.create(WorkspaceMember, {
        workspaceId: workspace.id,
        userId,
        role: 'owner',
      });
      await manager.save(member);

      const revenueVault = manager.create(Vault, {
        workspaceId: workspace.id,
        name: VIRTUAL_VAULT_NAMES.REVENUE,
        type: 'virtual',
        currentBalance: 0,
      });
      const expenseVault = manager.create(Vault, {
        workspaceId: workspace.id,
        name: VIRTUAL_VAULT_NAMES.EXPENSE,
        type: 'virtual',
        currentBalance: 0,
      });
      await manager.save([revenueVault, expenseVault]);

      const categories = DEFAULT_CATEGORIES.map((c) =>
        manager.create(Category, { workspaceId: workspace.id, name: c.name, groupName: c.groupName, icon: c.icon }),
      );
      await manager.save(categories);

      const achievements = DEFAULT_ACHIEVEMENTS.map((a) =>
        manager.create(Achievement, { workspaceId: workspace.id, key: a.key, name: a.name, description: a.description }),
      );
      await manager.save(achievements);

      return {
        id: workspace.id,
        name: workspace.name,
        type: workspace.type,
        owner_id: workspace.ownerId,
        created_at: workspace.createdAt,
      };
    });

    // Best-effort, after the workspace itself has committed — see the same
    // note on TransactionsService.create().
    await this.gamificationService.unlockFounderAchievement(response.id, userId);

    return response;
  }

  async getDetail(workspaceId: string) {
    const workspace = await this.workspacesRepository.findOne({ where: { id: workspaceId } });
    if (!workspace) {
      throw new AppException('NOT_FOUND', 'Không tìm thấy workspace');
    }
    const memberships = await this.membersRepository.find({ where: { workspaceId } });
    const usersRepository = this.dataSource.getRepository(User);
    const members = await Promise.all(
      memberships.map(async (membership) => {
        const user = await usersRepository.findOne({ where: { id: membership.userId } });
        return {
          user_id: membership.userId,
          full_name: user?.fullName ?? '',
          email: user?.email ?? '',
          role: membership.role,
        };
      }),
    );

    return {
      id: workspace.id,
      name: workspace.name,
      type: workspace.type,
      owner_id: workspace.ownerId,
      invite_code: workspace.inviteCode,
      members,
    };
  }

  /// "Qua mã mời" (Mục 8.5): anyone with the code joins as `role: 'member'`.
  async join(userId: string, dto: JoinWorkspaceDto) {
    const code = dto.invite_code.trim().toUpperCase();
    const workspace = await this.workspacesRepository.findOne({ where: { inviteCode: code } });
    if (!workspace) {
      throw new AppException('NOT_FOUND', 'Mã mời không hợp lệ');
    }
    const existing = await this.membersRepository.findOne({ where: { workspaceId: workspace.id, userId } });
    if (existing) {
      throw new AppException('CONFLICT', 'Bạn đã là thành viên của không gian làm việc này');
    }
    const member = this.membersRepository.create({ workspaceId: workspace.id, userId, role: 'member' });
    await this.membersRepository.save(member);

    // Mục 9 "Mời thành viên: +50 XP" — awarded to the owner whose invite
    // code brought in the new member.
    await this.gamificationService.awardXp(workspace.id, workspace.ownerId, 'member_invite');

    return { id: workspace.id, name: workspace.name, type: workspace.type, owner_id: workspace.ownerId };
  }

  /// Owner-only: rotates the invite code (e.g. if it leaked / they want a
  /// fresh one), returning the new code.
  async regenerateInviteCode(workspaceId: string, requesterId: string) {
    const workspace = await this.workspacesRepository.findOne({ where: { id: workspaceId } });
    if (!workspace) {
      throw new AppException('NOT_FOUND', 'Không tìm thấy workspace');
    }
    if (workspace.ownerId !== requesterId) {
      throw new AppException('FORBIDDEN', 'Chỉ chủ sở hữu mới có thể tạo lại mã mời');
    }
    workspace.inviteCode = generateInviteCode();
    await this.workspacesRepository.save(workspace);
    return { invite_code: workspace.inviteCode };
  }

  /// Owner-only: removes a member (can't remove the owner themselves — they
  /// must transfer ownership or delete the workspace, neither of which is
  /// in scope this pass).
  async removeMember(workspaceId: string, targetUserId: string, requesterId: string) {
    const workspace = await this.workspacesRepository.findOne({ where: { id: workspaceId } });
    if (!workspace) {
      throw new AppException('NOT_FOUND', 'Không tìm thấy workspace');
    }
    if (workspace.ownerId !== requesterId) {
      throw new AppException('FORBIDDEN', 'Chỉ chủ sở hữu mới có thể xoá thành viên');
    }
    if (targetUserId === workspace.ownerId) {
      throw new AppException('VALIDATION_ERROR', 'Không thể xoá chủ sở hữu khỏi không gian làm việc');
    }
    await this.membersRepository.delete({ workspaceId, userId: targetUserId });
    return { success: true };
  }
}
