import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_colors.dart';
import 'core/constants/dark_colors.dart';
import 'core/constants/game_colors.dart';
import 'core/theme/visual_style_provider.dart';
import 'features/auth/presentation/auth_notifier.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/register_screen.dart';
import 'features/auth/presentation/splash_screen.dart';
import 'features/budget/presentation/budget_management_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/debt/presentation/customer_list_screen.dart';
import 'features/gamification/presentation/gamification_screen.dart';
import 'features/onboarding/presentation/onboarding_notifier.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
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
    ref.listen(onboardingProvider, (_, _) => notifyListeners());
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
      final onboardingSeen = ref.read(onboardingProvider);
      if (onboardingSeen == false) {
        return location == '/onboarding' ? null : '/onboarding';
      }
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
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/workspaces', builder: (context, state) => const WorkspacePickerScreen()),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      GoRoute(path: '/gamification', builder: (context, state) => const GamificationScreen()),
      // Deep-link target for the "budget_over_limit" push notification
      // (see PushNotificationService._navigate) — not otherwise linked from
      // the bottom nav, only from Settings > Ngân sách.
      GoRoute(path: '/budgets', builder: (context, state) => const BudgetManagementScreen()),
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

/// Builds the app's [ThemeData] for the given visual style — this is what
/// makes *native* Flutter/Material chrome (AlertDialog, DatePicker,
/// DropdownMenu, TextField selection handles, ...) automatically follow
/// Cổ điển/Tối/Game Leon too, without every individual `showDialog` call
/// site needing its own color overrides.
ThemeData _buildTheme(AppVisualStyle style) {
  final (seed, background, surface, textPrimary, brightness) = switch (style) {
    AppVisualStyle.dark => (DarkColors.primary, DarkColors.background, DarkColors.surface, DarkColors.textPrimary, Brightness.dark),
    AppVisualStyle.gameLeon => (GameColors.cyan, GameColors.bgTop, GameColors.surface, GameColors.textPrimary, Brightness.dark),
    AppVisualStyle.classic => (AppColors.primary, AppColors.background, AppColors.surface, AppColors.textPrimary, Brightness.light),
  };
  // Game Leon's own background is already the darkest layer, so its
  // "sunken field" fill needs to step up to the surface tone instead of
  // trying to go a shade darker than the scaffold.
  final fieldFill = style == AppVisualStyle.gameLeon ? surface : background;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorSchemeSeed: seed,
    scaffoldBackgroundColor: background,
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: textPrimary,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: seed, width: 1.6)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.error, width: 1.2)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.error, width: 1.6)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}

class MoneyFlowApp extends ConsumerWidget {
  const MoneyFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final style = ref.watch(visualStyleProvider);

    return MaterialApp.router(
      title: 'Sổ Thu Chi',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(style),
      builder: (context, child) => AppLockGate(child: child ?? const SizedBox.shrink()),
      routerConfig: router,
    );
  }
}
