import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../domain/transaction.dart';

/// UI presentation helpers for [Transaction] — icon, color, Vietnamese
/// label and description line, shared by the Transactions tab and the
/// Dashboard's "recent transactions" list (Mục 12.3, 12.4).
Color transactionColor(TransactionType type) {
  switch (type) {
    case TransactionType.income:
    case TransactionType.debtDecrease:
      return AppColors.income;
    case TransactionType.expense:
      return AppColors.expense;
    case TransactionType.transfer:
      return AppColors.transfer;
    case TransactionType.debtIncrease:
      return AppColors.debt;
  }
}

IconData transactionIcon(TransactionType type) {
  switch (type) {
    case TransactionType.income:
      return Icons.arrow_downward;
    case TransactionType.expense:
      return Icons.arrow_upward;
    case TransactionType.transfer:
      return Icons.swap_horiz;
    case TransactionType.debtIncrease:
      return Icons.person_add_alt;
    case TransactionType.debtDecrease:
      return Icons.price_check;
  }
}

String transactionTypeLabel(TransactionType type) {
  switch (type) {
    case TransactionType.income:
      return 'Thu';
    case TransactionType.expense:
      return 'Chi';
    case TransactionType.transfer:
      return 'Chuyển tiền';
    case TransactionType.debtIncrease:
      return 'Bán thiếu';
    case TransactionType.debtDecrease:
      return 'Trả nợ';
  }
}

/// Sign prefix used before the formatted amount, e.g. "+1.000.000đ".
String transactionAmountSign(TransactionType type) {
  switch (type) {
    case TransactionType.income:
    case TransactionType.debtDecrease:
      return '+';
    case TransactionType.expense:
    case TransactionType.debtIncrease:
      return '-';
    case TransactionType.transfer:
      return '';
  }
}

/// Secondary description line, e.g. category name, or "Túi A → Túi B" for
/// transfers.
String transactionDescription(Transaction transaction) {
  switch (transaction.type) {
    case TransactionType.transfer:
      final from = transaction.fromVault?.name ?? '?';
      final to = transaction.toVault?.name ?? '?';
      return '$from → $to';
    case TransactionType.income:
      return transaction.category?.name ?? transaction.toVault?.name ?? '';
    case TransactionType.expense:
      return transaction.category?.name ?? transaction.fromVault?.name ?? '';
    case TransactionType.debtIncrease:
    case TransactionType.debtDecrease:
      return transaction.note ?? '';
  }
}
