import { Injectable } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource, Not } from 'typeorm';
import { WorkspaceMember } from '../workspaces/entities/workspace-member.entity';
import { FirebaseAdminService } from '../../common/firebase/firebase-admin.service';
import { UsersService } from '../users/users.service';

/// Push notifications (Mục — "Thông báo đẩy"), sent as a best-effort side
/// effect from workspace events (new transaction, recurring materialized,
/// budget crossed). No dedicated notification-log table — this is purely a
/// fire-to-FCM service, not a persisted inbox.
@Injectable()
export class NotificationsService {
  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
    private readonly firebaseAdminService: FirebaseAdminService,
    private readonly usersService: UsersService,
  ) {}

  async registerToken(userId: string, token: string): Promise<void> {
    await this.usersService.setFcmToken(userId, token);
  }

  async unregisterToken(userId: string): Promise<void> {
    await this.usersService.setFcmToken(userId, null);
  }

  /// Sends to every member of the workspace with a registered token,
  /// optionally skipping the user who caused the event (e.g. the person who
  /// just created the transaction doesn't need to be told about their own
  /// action).
  async notifyWorkspace(
    workspaceId: string,
    opts: { title: string; body: string; data?: Record<string, string>; excludeUserId?: string },
  ): Promise<void> {
    const members = await this.dataSource.getRepository(WorkspaceMember).find({
      where: { workspaceId, ...(opts.excludeUserId ? { userId: Not(opts.excludeUserId) } : {}) },
      relations: { user: true },
    });
    const tokens = members.map((m) => m.user?.fcmToken).filter((t): t is string => !!t);
    await this.firebaseAdminService.sendMulticast(tokens, opts.title, opts.body, opts.data);
  }
}
