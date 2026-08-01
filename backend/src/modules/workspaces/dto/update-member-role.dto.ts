import { IsIn } from 'class-validator';

/// Body for `PATCH /workspaces/:id/members/:userId/role` (Mục — "cài đặt
/// phân quyền từng người"). `'owner'` is deliberately not an accepted
/// value — see `WorkspacesService.updateMemberRole`'s doc comment.
export class UpdateMemberRoleDto {
  @IsIn(['manager', 'cashier', 'member'], { message: 'role không hợp lệ' })
  role: 'manager' | 'cashier' | 'member';
}
