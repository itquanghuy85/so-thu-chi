/// Centralized API configuration for Sổ Thu Chi.
///
/// The default [baseUrl] points at `10.0.2.2`, which is the special alias the
/// Android emulator uses to reach `localhost` on the host machine running the
/// backend (NestJS) on port 3000.
///
/// Override at build/run time for other targets, e.g.:
/// - iOS Simulator / physical device on the same Wi-Fi / web (Chrome):
///   `flutter run --dart-define=API_BASE_URL=http://localhost:3000/v1`
/// - Physical Android device on the same LAN:
///   `flutter run --dart-define=API_BASE_URL=http://<host-lan-ip>:3000/v1`
class ApiEndpoints {
  ApiEndpoints._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/v1',
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

  // Customers
  static String customers(String workspaceId) => '/workspaces/$workspaceId/customers';
  static String customerDebtHistory(String customerId) => '/customers/$customerId/debt-history';

  // Reports
  static const String cashflowReport = '/reports/cashflow';

  // Gamification
  static const String gamificationProfile = '/gamification/profile';
  static const String claimQuest = '/gamification/claim-quest';
}
