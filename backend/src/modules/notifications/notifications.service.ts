import { Injectable } from '@nestjs/common';
import { InjectDataSource, InjectRepository } from '@nestjs/typeorm';
import { DataSource, In, Repository } from 'typeorm';
import { WorkspaceMember } from '../workspaces/entities/workspace-member.entity';
import { FirebaseAdminService } from '../../common/firebase/firebase-admin.service';
import { PushToken } from './entities/push-token.entity';

/// Push notifications (Mục — "Thông báo đẩy"), sent as a best-effort side
/// effect from workspace events (new transaction, recurring materialized,
/// budget crossed). No dedicated notification-log table — this is purely a
/// fire-to-FCM service, not a persisted inbox.
@Injectable()
export class NotificationsService {
  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
    @InjectRepository(PushToken) private readonly pushTokensRepository: Repository<PushToken>,
    private readonly firebaseAdminService: FirebaseAdminService,
  ) {}

  /// Upserts by `token` (unique per device), not by user — see
  /// `PushToken`'s doc comment for why. Re-registering the same device
  /// under a different account (shared/reset device) just reassigns the
  /// row to the new `userId`.
  async registerToken(userId: string, token: string): Promise<void> {
    const existing = await this.pushTokensRepository.findOne({ where: { token } });
    if (existing) {
      existing.userId = userId;
      await this.pushTokensRepository.save(existing);
      return;
    }
    await this.pushTokensRepository.save(this.pushTokensRepository.create({ userId, token }));
  }

  /// Removes only this one device's row — logging out on phone A must not
  /// stop pushes to tablet B on the same account.
  async unregisterToken(token: string): Promise<void> {
    await this.pushTokensRepository.delete({ token });
  }

  /// Sends to every device registered by any member of the workspace,
  /// optionally skipping the one device that caused the event (e.g. the
  /// device that just created the transaction doesn't need to be told
  /// about its own action) — `excludeToken` is a *device*, not a *user*,
  /// so a second device signed into the same account still gets notified.
  async notifyWorkspace(
    workspaceId: string,
    opts: { title: string; body: string; data?: Record<string, string>; excludeToken?: string },
  ): Promise<void> {
    const members = await this.dataSource.getRepository(WorkspaceMember).find({ where: { workspaceId } });
    if (members.length === 0) return;
    const userIds = members.map((m) => m.userId);
    const tokenRows = await this.pushTokensRepository.find({ where: { userId: In(userIds) } });
    const tokens = tokenRows.map((t) => t.token).filter((token) => token !== opts.excludeToken);
    await this.firebaseAdminService.sendMulticast(tokens, opts.title, opts.body, opts.data);
  }
}
