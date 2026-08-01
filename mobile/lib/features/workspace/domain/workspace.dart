/// Workspace type: a small shop or a family budget.
enum WorkspaceType { shop, family }

WorkspaceType workspaceTypeFromString(String value) {
  return value == 'family' ? WorkspaceType.family : WorkspaceType.shop;
}

String workspaceTypeToString(WorkspaceType type) {
  return type == WorkspaceType.family ? 'family' : 'shop';
}

class WorkspaceMember {
  final String userId;
  final String fullName;
  final String email;
  final String role;

  const WorkspaceMember({required this.userId, required this.fullName, this.email = '', required this.role});

  factory WorkspaceMember.fromJson(Map<String, dynamic> json) {
    return WorkspaceMember(
      userId: json['user_id'] as String,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? '',
    );
  }
}

/// Workspace, as returned by `GET /workspaces` (list, includes
/// [memberCount]/[role]) and `POST /workspaces` (create, minimal fields).
class Workspace {
  final String id;
  final String name;
  final WorkspaceType type;
  final String ownerId;
  final int? memberCount;
  final String? role;
  final List<WorkspaceMember>? members;
  final String? inviteCode;

  const Workspace({
    required this.id,
    required this.name,
    required this.type,
    required this.ownerId,
    this.memberCount,
    this.role,
    this.members,
    this.inviteCode,
  });

  factory Workspace.fromJson(Map<String, dynamic> json) {
    return Workspace(
      id: json['id'] as String,
      name: json['name'] as String,
      type: workspaceTypeFromString(json['type'] as String? ?? 'shop'),
      ownerId: json['owner_id'] as String? ?? '',
      memberCount: json['member_count'] as int?,
      role: json['role'] as String?,
      members: (json['members'] as List<dynamic>?)
          ?.map((m) => WorkspaceMember.fromJson(m as Map<String, dynamic>))
          .toList(),
      inviteCode: json['invite_code'] as String?,
    );
  }
}
