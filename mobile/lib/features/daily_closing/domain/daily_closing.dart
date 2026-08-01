class DailyClosingEntry {
  final String vaultId;
  final String name;
  final num bookBalance;
  final num actualBalance;
  final num variance;

  const DailyClosingEntry({
    required this.vaultId,
    required this.name,
    required this.bookBalance,
    required this.actualBalance,
    required this.variance,
  });

  factory DailyClosingEntry.fromJson(Map<String, dynamic> json) => DailyClosingEntry(
        vaultId: json['vault_id'] as String,
        name: json['name'] as String,
        bookBalance: (json['book_balance'] as num?) ?? 0,
        actualBalance: (json['actual_balance'] as num?) ?? 0,
        variance: (json['variance'] as num?) ?? 0,
      );
}

/// "Chốt sổ cuối ngày": once per calendar day, counts every vault's actual
/// balance against the ledger's book balance. The variance-correction
/// itself reuses the same "Kiểm kê" (reconcile) action the standalone
/// per-vault quick action uses — this is purely the historical record.
class DailyClosing {
  final String id;
  final String closingDate;
  final List<DailyClosingEntry> entries;
  final num totalVariance;
  final String? note;
  final String closedByName;
  final DateTime createdAt;

  const DailyClosing({
    required this.id,
    required this.closingDate,
    required this.entries,
    required this.totalVariance,
    this.note,
    required this.closedByName,
    required this.createdAt,
  });

  factory DailyClosing.fromJson(Map<String, dynamic> json) => DailyClosing(
        id: json['id'] as String,
        closingDate: json['closing_date'] as String,
        entries: (json['entries'] as List<dynamic>? ?? [])
            .map((e) => DailyClosingEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalVariance: (json['total_variance'] as num?) ?? 0,
        note: json['note'] as String?,
        closedByName: json['closed_by_name'] as String? ?? '',
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      );
}
