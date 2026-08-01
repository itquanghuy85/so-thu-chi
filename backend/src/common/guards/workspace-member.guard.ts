import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { AppException } from '../exceptions/app.exception';
import { assertWorkspaceMember } from '../utils/workspace-access.util';

/**
 * Confirms the authenticated user is a member of the workspace referenced
 * by the request (path param `id`/`workspace_id`, query `workspace_id`, or
 * body `workspace_id`), and attaches `workspaceId` + `workspaceRole` to the
 * request for downstream handlers.
 *
 * Only attach this guard to routes where one of those sources genuinely
 * identifies the workspace. Routes like `/vaults/:id/reconcile`,
 * `/transactions/:id/void`, `/customers/:id/debt-history` have `:id`
 * pointing at a child resource instead — those do their own membership
 * check in the service after resolving the parent workspace_id.
 */
@Injectable()
export class WorkspaceMemberGuard implements CanActivate {
  constructor(@InjectDataSource() private readonly dataSource: DataSource) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const user = request.user;
    if (!user?.id) {
      throw new AppException('UNAUTHORIZED', 'Chưa đăng nhập');
    }

    const workspaceId: string | undefined =
      request.params?.workspace_id || request.params?.id || request.query?.workspace_id || request.body?.workspace_id;

    if (!workspaceId) {
      throw new AppException('VALIDATION_ERROR', 'Thiếu workspace_id', [
        { field: 'workspace_id', message: 'workspace_id là bắt buộc' },
      ]);
    }

    const role = await assertWorkspaceMember(this.dataSource, workspaceId, user.id);
    request.workspaceId = workspaceId;
    request.workspaceRole = role;
    return true;
  }
}
