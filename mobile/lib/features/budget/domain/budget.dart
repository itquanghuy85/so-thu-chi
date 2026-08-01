class Budget {
  final String id;
  final String? categoryId;
  final String? categoryName;
  final num limitAmount;
  final num spentThisMonth;
  final num remaining;
  final bool overBudget;

  const Budget({
    required this.id,
    this.categoryId,
    this.categoryName,
    required this.limitAmount,
    required this.spentThisMonth,
    required this.remaining,
    required this.overBudget,
  });

  /// 0.0–1.0+ (can exceed 1 when over budget) — callers should clamp for
  /// progress-bar display but may want the raw value for "% over" text.
  double get progress => limitAmount <= 0 ? 0 : (spentThisMonth / limitAmount).toDouble();

  factory Budget.fromJson(Map<String, dynamic> json) {
    final category = json['category'] as Map<String, dynamic>?;
    return Budget(
      id: json['id'] as String,
      categoryId: category?['id'] as String?,
      categoryName: category?['name'] as String?,
      limitAmount: (json['limit_amount'] as num?) ?? 0,
      spentThisMonth: (json['spent_this_month'] as num?) ?? 0,
      remaining: (json['remaining'] as num?) ?? 0,
      overBudget: json['over_budget'] as bool? ?? false,
    );
  }
}
