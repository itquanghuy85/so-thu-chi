/// Centralized API configuration for Sổ Thu Chi.
///
/// The default [baseUrl] points at the always-on production backend
/// (NestJS on Render + Postgres on Neon — see backend/README.md's
/// "Deploying to the cloud" section), so a normal `flutter run`/release
/// build works from anywhere with no local backend required. The free
/// Render tier spins down after ~15 min idle, so the very first request
/// after a quiet period can take several extra seconds while it wakes back
/// up — not a bug, just that tier's trade-off for being free.
///
/// Override at build/run time when working against a local backend instead:
/// - Android emulator (10.0.2.2 aliases the host machine's localhost):
///   `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/v1`
/// - iOS Simulator / physical device on the same Wi-Fi / web (Chrome):
///   `flutter run --dart-define=API_BASE_URL=http://localhost:3000/v1`
/// - Physical Android device on the same LAN:
///   `flutter run --dart-define=API_BASE_URL=http://<host-lan-ip>:3000/v1`
class ApiEndpoints {
  ApiEndpoints._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://so-thu-chi.onrender.com/v1',
  );

  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String me = '/auth/me';
  static const String socialLogin = '/auth/social-login';

  // Workspaces
  static const String workspaces = '/workspaces';
  static String workspace(String id) => '/workspaces/$id';
  static const String joinWorkspace = '/workspaces/join';
  static String regenerateInviteCode(String id) => '/workspaces/$id/invite-code';
  static String removeMember(String workspaceId, String userId) => '/workspaces/$workspaceId/members/$userId';

  // Vaults
  static String vaults(String workspaceId) => '/workspaces/$workspaceId/vaults';
  static String reconcileVault(String vaultId) => '/vaults/$vaultId/reconcile';

  // Categories
  static String categories(String workspaceId) => '/workspaces/$workspaceId/categories';
  static String category(String workspaceId, String categoryId) => '/workspaces/$workspaceId/categories/$categoryId';

  // Transactions
  static const String transactions = '/transactions';
  static String voidTransaction(String id) => '/transactions/$id/void';
  static String editTransaction(String id) => '/transactions/$id';

  // Customers
  static String customers(String workspaceId) => '/workspaces/$workspaceId/customers';
  static String customerDebtHistory(String customerId) => '/customers/$customerId/debt-history';

  // Reports
  static const String cashflowReport = '/reports/cashflow';
  static const String dailySummaryReport = '/reports/daily-summary';

  // Gamification
  static const String gamificationProfile = '/gamification/profile';
  static const String claimQuest = '/gamification/claim-quest';

  // Budgets
  static String budgets(String workspaceId) => '/workspaces/$workspaceId/budgets';
  static String budget(String workspaceId, String budgetId) => '/workspaces/$workspaceId/budgets/$budgetId';

  // Recurring transactions
  static String recurring(String workspaceId) => '/workspaces/$workspaceId/recurring';
  static String recurringItem(String workspaceId, String id) => '/workspaces/$workspaceId/recurring/$id';
  static String recurringRunDue(String workspaceId) => '/workspaces/$workspaceId/recurring/run-due';

  // Shifts
  static String shifts(String workspaceId) => '/workspaces/$workspaceId/shifts';
  static String shiftCurrent(String workspaceId) => '/workspaces/$workspaceId/shifts/current';
  static String shiftOpen(String workspaceId) => '/workspaces/$workspaceId/shifts/open';
  static String shiftClose(String workspaceId, String shiftId) => '/workspaces/$workspaceId/shifts/$shiftId/close';

  // Push notifications
  static const String fcmToken = '/notifications/fcm-token';

  // Daily closings (chốt sổ cuối ngày)
  static String dailyClosings(String workspaceId) => '/workspaces/$workspaceId/daily-closings';
  static String dailyClosingToday(String workspaceId) => '/workspaces/$workspaceId/daily-closings/today';

  // Audit logs
  static String auditLogs(String workspaceId) => '/workspaces/$workspaceId/audit-logs';
}
