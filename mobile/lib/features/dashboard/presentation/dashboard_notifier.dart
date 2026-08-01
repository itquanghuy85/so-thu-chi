import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/current_workspace_provider.dart';
import '../../transaction/data/transaction_repository.dart';
import '../../transaction/domain/transaction.dart';
import '../../vault/data/vault_repository.dart';
import '../../vault/domain/vault.dart';

class DashboardData {
  final num totalBalance;
  final num todayIncome;
  final num todayExpense;
  final List<Vault> vaults;
  final List<Transaction> recentTransactions;

  const DashboardData({
    required this.totalBalance,
    required this.todayIncome,
    required this.todayExpense,
    required this.vaults,
    required this.recentTransactions,
  });

  num get todayNet => todayIncome - todayExpense;
}

/// Aggregates the data the Dashboard tab needs (Mục 12.3): total balance
/// (sum of non-virtual vault balances), today's income/expense, the vault
/// carousel and the 5 most recent transactions.
///
/// **Approximation**: the backend has no "transactions for today" endpoint,
/// so today's income/expense is derived client-side by filtering the most
/// recent page of transactions (`page=1&limit=20`, assumed newest-first) to
/// those created today (device-local date). If a workspace has more than
/// ~20 transactions on the current day, this undercounts — acceptable for
/// MVP; a dedicated `/reports/cashflow?period=today` (or similar) endpoint
/// would remove the approximation in a later sprint.
final dashboardDataProvider = FutureProvider.autoDispose<DashboardData>((ref) async {
  final workspaceId = ref.watch(currentWorkspaceIdProvider);
  final vaultRepo = ref.watch(vaultRepositoryProvider);
  final transactionRepo = ref.watch(transactionRepositoryProvider);

  final results = await Future.wait([
    vaultRepo.getVaults(workspaceId),
    transactionRepo.getTransactions(workspaceId: workspaceId, page: 1, limit: 20),
  ]);
  final vaults = results[0] as List<Vault>;
  final transactionPage = results[1] as TransactionPage;

  final now = DateTime.now();
  bool isToday(DateTime dt) => dt.year == now.year && dt.month == now.month && dt.day == now.day;

  num todayIncome = 0;
  num todayExpense = 0;
  for (final t in transactionPage.data) {
    if (t.isVoided || !isToday(t.createdAt)) continue;
    if (t.type == TransactionType.income) todayIncome += t.amount;
    if (t.type == TransactionType.expense) todayExpense += t.amount;
  }

  final totalBalance = vaults.fold<num>(0, (sum, v) => sum + v.currentBalance);

  return DashboardData(
    totalBalance: totalBalance,
    todayIncome: todayIncome,
    todayExpense: todayExpense,
    vaults: vaults,
    recentTransactions: transactionPage.data.take(5).toList(),
  );
});
