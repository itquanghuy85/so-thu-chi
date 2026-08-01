import '../../transaction/domain/transaction.dart';

enum RecurringFrequency { daily, weekly, monthly }

RecurringFrequency frequencyFromString(String value) {
  switch (value) {
    case 'weekly':
      return RecurringFrequency.weekly;
    case 'monthly':
      return RecurringFrequency.monthly;
    default:
      return RecurringFrequency.daily;
  }
}

String frequencyToString(RecurringFrequency f) => switch (f) {
      RecurringFrequency.daily => 'daily',
      RecurringFrequency.weekly => 'weekly',
      RecurringFrequency.monthly => 'monthly',
    };

String frequencyLabel(RecurringFrequency f) => switch (f) {
      RecurringFrequency.daily => 'Hàng ngày',
      RecurringFrequency.weekly => 'Hàng tuần',
      RecurringFrequency.monthly => 'Hàng tháng',
    };

class RecurringRef {
  final String id;
  final String name;

  const RecurringRef({required this.id, required this.name});

  factory RecurringRef.fromJson(Map<String, dynamic> json) => RecurringRef(id: json['id'] as String, name: json['name'] as String);
}

class RecurringTransaction {
  final String id;
  final TransactionType type;
  final num amount;
  final String? note;
  final RecurringFrequency frequency;
  final DateTime nextRunDate;
  final bool active;
  final RecurringRef? category;
  final RecurringRef? fromVault;
  final RecurringRef? toVault;
  final RecurringRef? customer;

  const RecurringTransaction({
    required this.id,
    required this.type,
    required this.amount,
    this.note,
    required this.frequency,
    required this.nextRunDate,
    required this.active,
    this.category,
    this.fromVault,
    this.toVault,
    this.customer,
  });

  factory RecurringTransaction.fromJson(Map<String, dynamic> json) {
    return RecurringTransaction(
      id: json['id'] as String,
      type: transactionTypeFromString(json['type'] as String? ?? 'income'),
      amount: (json['amount'] as num?) ?? 0,
      note: json['note'] as String?,
      frequency: frequencyFromString(json['frequency'] as String? ?? 'monthly'),
      nextRunDate: DateTime.tryParse(json['next_run_date'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      active: json['active'] as bool? ?? true,
      category: json['category'] is Map<String, dynamic> ? RecurringRef.fromJson(json['category'] as Map<String, dynamic>) : null,
      fromVault: json['from_vault'] is Map<String, dynamic> ? RecurringRef.fromJson(json['from_vault'] as Map<String, dynamic>) : null,
      toVault: json['to_vault'] is Map<String, dynamic> ? RecurringRef.fromJson(json['to_vault'] as Map<String, dynamic>) : null,
      customer: json['customer'] is Map<String, dynamic> ? RecurringRef.fromJson(json['customer'] as Map<String, dynamic>) : null,
    );
  }
}
