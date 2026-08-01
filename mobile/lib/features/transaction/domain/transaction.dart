/// Transaction type, matches the backend enum exactly.
enum TransactionType { income, expense, transfer, debtIncrease, debtDecrease }

TransactionType transactionTypeFromString(String value) {
  switch (value) {
    case 'expense':
      return TransactionType.expense;
    case 'transfer':
      return TransactionType.transfer;
    case 'debt_increase':
      return TransactionType.debtIncrease;
    case 'debt_decrease':
      return TransactionType.debtDecrease;
    default:
      return TransactionType.income;
  }
}

String transactionTypeToString(TransactionType type) {
  switch (type) {
    case TransactionType.income:
      return 'income';
    case TransactionType.expense:
      return 'expense';
    case TransactionType.transfer:
      return 'transfer';
    case TransactionType.debtIncrease:
      return 'debt_increase';
    case TransactionType.debtDecrease:
      return 'debt_decrease';
  }
}

/// Minimal nested vault/category references embedded in a transaction, as
/// returned by `GET /transactions`.
class TransactionRef {
  final String id;
  final String name;

  const TransactionRef({required this.id, required this.name});

  factory TransactionRef.fromJson(Map<String, dynamic> json) {
    return TransactionRef(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}

class Transaction {
  final String id;
  final TransactionType type;
  final num amount;
  final String? note;
  final TransactionRef? category;
  final TransactionRef? fromVault;
  final TransactionRef? toVault;
  final TransactionRef? customer;
  final DateTime createdAt;
  final String status;

  /// Giá vốn (Mục — "tính lợi nhuận theo vốn"), only ever set on an
  /// `income` transaction — null means "not recorded", not zero.
  final num? costAmount;

  /// `amount - costAmount` for an income transaction that recorded a cost;
  /// null otherwise (never fabricated client-side — this mirrors exactly
  /// what the backend computed and returned).
  final num? profit;

  /// True only for a client-side optimistic echo of a transaction created
  /// while offline and still sitting in the sync queue (Mục 14) — never
  /// set from a real server response. Lets the UI show a "Chờ đồng bộ"
  /// badge instead of pretending the write already reached the backend.
  final bool pending;

  const Transaction({
    required this.id,
    required this.type,
    required this.amount,
    this.note,
    this.category,
    this.fromVault,
    this.toVault,
    this.customer,
    required this.createdAt,
    required this.status,
    this.costAmount,
    this.profit,
    this.pending = false,
  });

  bool get isVoided => status == 'voided';

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      type: transactionTypeFromString(json['type'] as String? ?? 'income'),
      amount: (json['amount'] as num?) ?? 0,
      note: json['note'] as String?,
      category: json['category'] is Map<String, dynamic>
          ? TransactionRef.fromJson(json['category'] as Map<String, dynamic>)
          : null,
      fromVault: json['from_vault'] is Map<String, dynamic>
          ? TransactionRef.fromJson(json['from_vault'] as Map<String, dynamic>)
          : null,
      toVault: json['to_vault'] is Map<String, dynamic>
          ? TransactionRef.fromJson(json['to_vault'] as Map<String, dynamic>)
          : null,
      customer: json['customer'] is Map<String, dynamic>
          ? TransactionRef.fromJson(json['customer'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      status: json['status'] as String? ?? 'completed',
      costAmount: json['cost_amount'] as num?,
      profit: json['profit'] as num?,
    );
  }
}

class TransactionPage {
  final List<Transaction> data;
  final int page;
  final int totalPages;

  const TransactionPage({required this.data, required this.page, required this.totalPages});

  factory TransactionPage.fromJson(Map<String, dynamic> json) {
    final pagination = json['pagination'] as Map<String, dynamic>? ?? {};
    return TransactionPage(
      data: (json['data'] as List<dynamic>? ?? [])
          .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: (pagination['page'] as num?)?.toInt() ?? 1,
      totalPages: (pagination['total_pages'] as num?)?.toInt() ?? 1,
    );
  }
}
