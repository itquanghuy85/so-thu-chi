class VaultSnapshotEntry {
  final String vaultId;
  final String name;
  final num balance;

  const VaultSnapshotEntry({required this.vaultId, required this.name, required this.balance});

  factory VaultSnapshotEntry.fromJson(Map<String, dynamic> json) => VaultSnapshotEntry(
        vaultId: json['vault_id'] as String,
        name: json['name'] as String,
        balance: (json['balance'] as num?) ?? 0,
      );
}

/// A work shift (Mục — "Ca làm việc"): opened at clock-in (snapshots every
/// real-money vault's balance), closed at clock-out (snapshots again).
/// Income/expense-during-shift is derived server-side from transactions
/// created in the [openedAt, closedAt) window — see ShiftsService.summary.
class Shift {
  final String id;
  final DateTime openedAt;
  final DateTime? closedAt;
  final List<VaultSnapshotEntry> openingSnapshot;
  final List<VaultSnapshotEntry> closingSnapshot;
  final String? note;
  final num incomeDuringShift;
  final num expenseDuringShift;
  final String? userName;

  const Shift({
    required this.id,
    required this.openedAt,
    this.closedAt,
    required this.openingSnapshot,
    required this.closingSnapshot,
    this.note,
    required this.incomeDuringShift,
    required this.expenseDuringShift,
    this.userName,
  });

  bool get isOpen => closedAt == null;

  num get netDuringShift => incomeDuringShift - expenseDuringShift;

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      id: json['id'] as String,
      openedAt: DateTime.parse(json['opened_at'] as String).toLocal(),
      closedAt: json['closed_at'] != null ? DateTime.parse(json['closed_at'] as String).toLocal() : null,
      openingSnapshot: (json['opening_snapshot'] as List<dynamic>? ?? [])
          .map((e) => VaultSnapshotEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      closingSnapshot: (json['closing_snapshot'] as List<dynamic>? ?? [])
          .map((e) => VaultSnapshotEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      note: json['note'] as String?,
      incomeDuringShift: (json['income_during_shift'] as num?) ?? 0,
      expenseDuringShift: (json['expense_during_shift'] as num?) ?? 0,
      userName: json['user_name'] as String?,
    );
  }
}
