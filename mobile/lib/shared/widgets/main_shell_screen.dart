import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/offline/sync_queue_service.dart';
import 'offline_banner.dart';

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Color color;

  const _NavItem({required this.icon, required this.selectedIcon, required this.label, required this.color});
}

const _navItems = [
  _NavItem(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard_rounded, label: 'Tổng quan', color: AppColors.primary),
  _NavItem(icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long_rounded, label: 'Giao dịch', color: AppColors.transfer),
  _NavItem(icon: Icons.account_balance_wallet_outlined, selectedIcon: Icons.account_balance_wallet_rounded, label: 'Túi tiền', color: AppColors.secondary),
  _NavItem(icon: Icons.people_outline, selectedIcon: Icons.people_alt_rounded, label: 'Công nợ', color: AppColors.debt),
  _NavItem(icon: Icons.pie_chart_outline, selectedIcon: Icons.pie_chart_rounded, label: 'Báo cáo', color: Color(0xFF11998E)),
];

/// Bottom-nav shell wrapping the 5 main tabs: Dashboard, Transactions,
/// Vaults, Debt/Customers, Reports. Settings is reached via the gear icon
/// on the Dashboard header (pushed on top, outside the shell), per Mục
/// 12.13. Each tab has its own accent color (matching that section's color
/// elsewhere in the app) so the bar reads as lively rather than a flat
/// grey/blue Material default.
class MainShellScreen extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainShellScreen({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Side-effect-only watch: keeps the auto-flush-on-reconnect listener
    // alive for the lifetime of the main shell (Mục 14).
    ref.watch(autoFlushOnReconnectProvider);

    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 72,
            child: Row(
              children: [
                for (var i = 0; i < _navItems.length; i++)
                  Expanded(
                    child: _NavButton(
                      item: _navItems[i],
                      selected: i == navigationShell.currentIndex,
                      onTap: () => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: selected ? item.color.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? item.selectedIcon : item.icon,
              color: selected ? item.color : item.color.withValues(alpha: 0.55),
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? item.color : item.color.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
