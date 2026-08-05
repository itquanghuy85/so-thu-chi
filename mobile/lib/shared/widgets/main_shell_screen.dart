import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/notifications/push_notification_service.dart';
import '../../core/offline/sync_queue_service.dart';
import '../../core/theme/screen_neutrals.dart';
import '../../core/theme/section_accents.dart';
import '../../core/theme/visual_style_provider.dart';
import 'offline_banner.dart';

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final AppSection section;

  const _NavItem({required this.icon, required this.selectedIcon, required this.label, required this.section});
}

const _navItems = [
  _NavItem(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard_rounded, label: 'Tổng quan', section: AppSection.dashboard),
  _NavItem(icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long_rounded, label: 'Giao dịch', section: AppSection.transactions),
  _NavItem(icon: Icons.account_balance_wallet_outlined, selectedIcon: Icons.account_balance_wallet_rounded, label: 'Túi tiền', section: AppSection.vaults),
  _NavItem(icon: Icons.people_outline, selectedIcon: Icons.people_alt_rounded, label: 'Công nợ', section: AppSection.debt),
  _NavItem(icon: Icons.pie_chart_outline, selectedIcon: Icons.pie_chart_rounded, label: 'Báo cáo', section: AppSection.reports),
];

/// Bottom-nav shell wrapping the 5 main tabs: Dashboard, Transactions,
/// Vaults, Debt/Customers, Reports. Settings is reached via the gear icon
/// on the Dashboard header (pushed on top, outside the shell), per Mục
/// 12.13. Each tab has its own accent color (`sectionAccent`, shared with
/// that tab's `SectionAppBar` and Settings tile) so the bar reads as lively
/// rather than a flat grey/blue Material default, across all 3 visual
/// styles (Mục 16.2 "Game Leon" + Tối).
class MainShellScreen extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainShellScreen({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Side-effect-only watch: keeps the auto-flush-on-reconnect listener
    // alive for the lifetime of the main shell (Mục 14).
    ref.watch(autoFlushOnReconnectProvider);
    // Registers this device's FCM token once a session + workspace exist
    // (Mục — "Thông báo đẩy"); MainShellScreen only renders past that point.
    ref.watch(pushNotificationInitProvider);
    final style = ref.watch(visualStyleProvider);
    final n = neutralsFor(style);

    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: navigationShell),
        ],
      ),
      // Nút AI chat nhanh — nổi phía trên bottom nav, không cản tab bar
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'ai_chat_fab',
        tooltip: 'Trợ lý AI',
        backgroundColor: const Color(0xFF6C63FF),
        onPressed: () => context.push('/ai-chat'),
        child: const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: n.surface,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(22), topRight: Radius.circular(22)),
          border: n.isGame ? Border(top: BorderSide(color: n.divider, width: 1)) : null,
          boxShadow: [
            BoxShadow(
              color: n.isGame ? Colors.black.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(22), topRight: Radius.circular(22)),
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
                        style: style,
                        neutrals: n,
                        onTap: () => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex),
                      ),
                    ),
                ],
              ),
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
  final AppVisualStyle style;
  final ScreenNeutrals neutrals;
  final VoidCallback onTap;

  const _NavButton({required this.item, required this.selected, required this.style, required this.neutrals, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = sectionAccent(item.section, style);
    final dimColor = neutrals.isGame ? neutrals.textSecondary : color.withValues(alpha: 0.55);
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: neutrals.isGame ? 0.18 : 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: selected && neutrals.isGame ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 12)] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? item.selectedIcon : item.icon,
              color: selected ? color : dimColor,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? color : dimColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
