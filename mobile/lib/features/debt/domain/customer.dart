class Customer {
  final String id;
  final String name;
  final String? phone;
  final num debtBalance;
  final DateTime? createdAt;

  const Customer({
    required this.id,
    required this.name,
    this.phone,
    required this.debtBalance,
    this.createdAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      debtBalance: (json['debt_balance'] as num?) ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal(),
    );
  }
}

/// A single entry in a customer's debt history (`GET
/// /customers/:id/debt-history`) — a summarized transaction.
class DebtHistoryEntry {
  final String id;
  final String type; // debt_increase | debt_decrease
  final num amount;
  final String? note;
  final DateTime createdAt;

  const DebtHistoryEntry({
    required this.id,
    required this.type,
    required this.amount,
    this.note,
    required this.createdAt,
  });

  factory DebtHistoryEntry.fromJson(Map<String, dynamic> json) {
    return DebtHistoryEntry(
      id: json['id'] as String,
      type: json['type'] as String? ?? '',
      amount: (json['amount'] as num?) ?? 0,
      note: json['note'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
