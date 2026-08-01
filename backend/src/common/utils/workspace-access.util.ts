import { DataSource } from 'typeorm';
import { AppException } from '../exceptions/app.exception';
import { WorkspaceMember, WorkspaceRole } from '../../modules/workspaces/entities/workspace-member.entity';

/**
 * Verifies the given user is a member of the given workspace, throwing a
 * 403 FORBIDDEN AppException otherwise. Returns the member's role so
 * callers/guards can attach it to the request or enforce role checks.
 *
 * Used both by WorkspaceMemberGuard (for routes shaped as
 * /workspaces/:id/... or carrying workspace_id in query/body) and directly
 * by services for routes where the workspace must first be resolved via a
 * child resource (e.g. /vaults/:id/reconcile -> vault.workspace_id).
 */
export async function assertWorkspaceMember(
  dataSource: DataSource,
  workspaceId: string,
  userId: string,
): Promise<WorkspaceRole> {
  const member = await dataSource.getRepository(WorkspaceMember).findOne({
    where: { workspaceId, userId },
  });
  if (!member) {
    throw new AppException('FORBIDDEN', 'Bạn không phải là thành viên của workspace này');
  }
  return member.role;
}
