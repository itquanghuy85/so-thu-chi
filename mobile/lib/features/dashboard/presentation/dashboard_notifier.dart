import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/current_workspace_provider.dart';
import '../../recurring/data/recurring_repository.dart';
import '../../reports/data/reports_repository.dart';
import '../../reports/domain/cashflow_report.dart';
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
/// (sum of non-virtual vault balances), today's income/expense/profit (a
/// real server-side `GET /reports/daily-summary` for today — not a
/// client-side approximation, see `ReportsService.dailySummary`), the vault
/// carousel and the 5 most recent transactions.
final dashboardDataProvider = FutureProvider.autoDispose<DashboardData>((ref) async {
  final workspaceId = ref.watch(currentWorkspaceIdProvider);
  final vaultRepo = ref.watch(vaultRepositoryProvider);
  final transactionRepo = ref.watch(transactionRepositoryProvider);
  final reportsRepo = ref.watch(reportsRepositoryProvider);

  // There's no server-side scheduler for recurring transactions (Mục
  // design) — materializing due occurrences on every Dashboard load is the
  // trigger. Best-effort: if this fails (e.g. offline), the Dashboard still
  // renders from whatever data is fetchable; the next load retries.
  try {
    await ref.read(recurringRepositoryProvider).runDue(workspaceId);
  } catch (_) {}

  final today = DateTime.now();
  final results = await Future.wait([
    vaultRepo.getVaults(workspaceId),
    transactionRepo.getTransactions(workspaceId: workspaceId, page: 1, limit: 5),
    reportsRepo.getDailySummary(workspaceId: workspaceId, fromDate: today, toDate: today),
  ]);
  final vaults = results[0] as List<Vault>;
  final transactionPage = results[1] as TransactionPage;
  final dailySummary = results[2] as List<DailySummary>;

  final totalBalance = vaults.fold<num>(0, (sum, v) => sum + v.currentBalance);
  final todaySummary = dailySummary.isEmpty ? null : dailySummary.first;

  return DashboardData(
    totalBalance: totalBalance,
    todayIncome: todaySummary?.income ?? 0,
    todayExpense: todaySummary?.expense ?? 0,
    vaults: vaults,
    recentTransactions: transactionPage.data.take(5).toList(),
  );
});
