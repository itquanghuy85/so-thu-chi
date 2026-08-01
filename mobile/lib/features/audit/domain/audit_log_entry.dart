class AuditLogEntry {
  final String id;
  final String action;
  final String entityType;
  final String entityId;
  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;
  final String? note;
  final String userName;
  final DateTime createdAt;

  const AuditLogEntry({
    required this.id,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.before,
    this.after,
    this.note,
    required this.userName,
    required this.createdAt,
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) => AuditLogEntry(
        id: json['id'] as String,
        action: json['action'] as String? ?? '',
        entityType: json['entity_type'] as String? ?? '',
        entityId: json['entity_id'] as String? ?? '',
        before: json['before'] is Map<String, dynamic> ? json['before'] as Map<String, dynamic> : null,
        after: json['after'] is Map<String, dynamic> ? json['after'] as Map<String, dynamic> : null,
        note: json['note'] as String?,
        userName: json['user_name'] as String? ?? '',
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      );
}

class AuditLogPage {
  final List<AuditLogEntry> data;
  final int page;
  final int totalPages;

  const AuditLogPage({required this.data, required this.page, required this.totalPages});

  factory AuditLogPage.fromJson(Map<String, dynamic> json) {
    final pagination = json['pagination'] as Map<String, dynamic>? ?? {};
    return AuditLogPage(
      data: (json['data'] as List<dynamic>? ?? []).map((e) => AuditLogEntry.fromJson(e as Map<String, dynamic>)).toList(),
      page: (pagination['page'] as num?)?.toInt() ?? 1,
      totalPages: (pagination['total_pages'] as num?)?.toInt() ?? 1,
    );
  }
}

String auditActionLabel(String action) => switch (action) {
      'transaction_edit' => 'Sửa giao dịch',
      'transaction_void' => 'Hủy giao dịch',
      'daily_closing' => 'Chốt sổ cuối ngày',
      _ => action,
    };
