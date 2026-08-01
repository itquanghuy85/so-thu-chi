import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_colors.dart';
import 'features/auth/presentation/auth_notifier.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/register_screen.dart';
import 'features/auth/presentation/splash_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/debt/presentation/customer_list_screen.dart';
import 'features/gamification/presentation/gamification_screen.dart';
import 'features/reports/presentation/reports_overview_screen.dart';
import 'features/security/presentation/app_lock_gate.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/transaction/presentation/transaction_list_screen.dart';
import 'features/vault/presentation/vault_list_screen.dart';
import 'features/workspace/presentation/workspace_notifier.dart';
import 'features/workspace/presentation/workspace_picker_screen.dart';
import 'shared/widgets/main_shell_screen.dart';

/// Notifies [GoRouter] to re-evaluate `redirect` whenever auth or workspace
/// selection state changes (e.g. login success, logout, workspace switch).
class _GoRouterRefreshNotifier extends ChangeNotifier {
  _GoRouterRefreshNotifier(Ref ref) {
    ref.listen(authNotifierProvider, (_, _) => notifyListeners());
    ref.listen(workspaceNotifierProvider, (_, _) => notifyListeners());
  }
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _GoRouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final workspaceState = ref.read(workspaceNotifierProvider);
      final location = state.matchedLocation;

      const authRoutes = {'/login', '/register'};

      if (authState.status == AuthStatus.unknown) {
        return location == '/splash' ? null : '/splash';
      }

      if (authState.status == AuthStatus.unauthenticated) {
        return authRoutes.contains(location) ? null : '/login';
      }

      // Authenticated from here on.
      if (workspaceState.selected == null) {
        if (workspaceState.workspaces.isEmpty && !workspaceState.isLoading) {
          // Kick off the load once so a previously-selected workspace
          // (persisted in secure storage) is restored without the user
          // having to tap it again after an app relaunch.
          Future.microtask(() => ref.read(workspaceNotifierProvider.notifier).loadWorkspaces());
        }
        return location == '/workspaces' ? null : '/workspaces';
      }

      if (location == '/splash' || authRoutes.contains(location) || location == '/workspaces') {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/workspaces', builder: (context, state) => const WorkspacePickerScreen()),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      GoRoute(path: '/gamification', builder: (context, state) => const GamificationScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainShellScreen(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/transactions', builder: (context, state) => const TransactionListScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/vaults', builder: (context, state) => const VaultListScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/debt', builder: (context, state) => const CustomerListScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/reports', builder: (context, state) => const ReportsOverviewScreen()),
          ]),
        ],
      ),
    ],
  );
});

class MoneyFlowApp extends ConsumerWidget {
  const MoneyFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'Sổ Thu Chi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      builder: (context, child) => AppLockGate(child: child ?? const SizedBox.shrink()),
      routerConfig: router,
    );
  }
}
