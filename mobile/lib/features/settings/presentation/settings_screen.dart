import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/dark_colors.dart';
import '../../../core/constants/game_colors.dart';
import '../../../core/theme/screen_neutrals.dart';
import '../../../core/theme/section_accents.dart';
import '../../../core/theme/visual_style_provider.dart';
import '../../../shared/providers/current_workspace_provider.dart';
import '../../../shared/widgets/initials_avatar.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../../core/notifications/notifications_repository.dart';
import '../../../core/notifications/push_notification_service.dart';
import '../../../shared/providers/secure_storage_provider.dart';
import '../../audit/presentation/audit_log_screen.dart';
import '../../budget/presentation/budget_management_screen.dart';
import '../../category/presentation/category_management_screen.dart';
import '../../daily_closing/presentation/daily_closing_screen.dart';
import '../../recurring/presentation/recurring_list_screen.dart';
import '../../security/presentation/security_settings_screen.dart';
import '../../shift/presentation/shift_screen.dart';
import '../../../shared/widgets/section_app_bar.dart';
import '../../workspace/domain/workspace.dart';
import '../../workspace/presentation/member_management_screen.dart';

/// Cài đặt (Mục 12.13). Integrations, notifications, theme switcher and
/// voice config remain next-sprint scope (see mobile/README.md).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(currentWorkspaceProvider);
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;

    final style = ref.watch(visualStyleProvider);
    final n = neutralsFor(style);
    final accent = sectionAccent(AppSection.settings, style);

    return Scaffold(
      backgroundColor: n.tint(accent),
      appBar: SectionAppBar(title: 'Cài đặt', style: style),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (user != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: n.isGame ? [accent, Color.lerp(accent, Colors.black, 0.35)!] : AppColors.heroGradient(accent), begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
                boxShadow: n.isGame ? [BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))] : null,
              ),
              child: Row(
                children: [
                  InitialsAvatar(name: user.fullName, radius: 26),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.fullName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(user.email, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Không gian làm việc',
            neutrals: n,
            children: [
              if (workspace != null)
                _SettingsTile(
                  icon: workspace.type == WorkspaceType.shop ? Icons.storefront : Icons.house_outlined,
                  color: accent,
                  title: workspace.name,
                  subtitle: workspace.type == WorkspaceType.shop ? 'Cửa hàng' : 'Gia đình',
                  neutrals: n,
                ),
              if (workspace != null && user != null)
                _SettingsTile(
                  icon: Icons.people_outline,
                  color: sectionAccent(AppSection.member, style),
                  title: 'Thành viên',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MemberManagementScreen(workspaceId: workspace.id, currentUserId: user.id),
                    ),
                  ),
                  showChevron: true,
                  neutrals: n,
                ),
              _SettingsTile(
                icon: Icons.swap_horiz,
                color: sectionAccent(AppSection.vaults, style),
                title: 'Đổi không gian làm việc',
                onTap: () => _switchWorkspace(context, ref),
                showChevron: true,
                neutrals: n,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _VisualStyleSection(),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Tuỳ chỉnh',
            neutrals: n,
            children: [
              _SettingsTile(
                icon: Icons.pie_chart_outline,
                color: sectionAccent(AppSection.budget, style),
                title: 'Ngân sách',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BudgetManagementScreen()),
                ),
                showChevron: true,
                neutrals: n,
              ),
              _SettingsTile(
                icon: Icons.repeat_rounded,
                color: sectionAccent(AppSection.recurring, style),
                title: 'Giao dịch định kỳ',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RecurringListScreen()),
                ),
                showChevron: true,
                neutrals: n,
              ),
              _SettingsTile(
                icon: Icons.badge_outlined,
                color: sectionAccent(AppSection.shift, style),
                title: 'Ca làm việc',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ShiftScreen()),
                ),
                showChevron: true,
                neutrals: n,
              ),
              _SettingsTile(
                icon: Icons.fact_check_outlined,
                color: sectionAccent(AppSection.dailyClosing, style),
                title: 'Chốt sổ cuối ngày',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DailyClosingScreen()),
                ),
                showChevron: true,
                neutrals: n,
              ),
              _SettingsTile(
                icon: Icons.category_outlined,
                color: sectionAccent(AppSection.category, style),
                title: 'Danh mục thu/chi',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CategoryManagementScreen()),
                ),
                showChevron: true,
                neutrals: n,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Bảo mật',
            neutrals: n,
            children: [
              _SettingsTile(
                icon: Icons.fingerprint,
                color: sectionAccent(AppSection.security, style),
                title: 'PIN / Vân tay',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SecuritySettingsScreen()),
                ),
                showChevron: true,
                neutrals: n,
              ),
              _SettingsTile(
                icon: Icons.history_rounded,
                color: sectionAccent(AppSection.audit, style),
                title: 'Lịch sử chỉnh sửa',
                subtitle: 'Nhật ký sửa/xóa giao dịch, chốt sổ',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AuditLogScreen()),
                ),
                showChevron: true,
                neutrals: n,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Tài khoản',
            neutrals: n,
            children: [
              _SettingsTile(
                icon: Icons.logout,
                color: AppColors.error,
                title: 'Đăng xuất',
                titleColor: AppColors.error,
                onTap: () => _logout(context, ref),
                neutrals: n,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('Sổ Thu Chi • MVP', style: TextStyle(color: n.textSecondary, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Future<void> _switchWorkspace(BuildContext context, WidgetRef ref) async {
    await ref.read(workspaceNotifierProvider.notifier).clearSelection();
    // Router redirect (app.dart) sends the user back to the workspace
    // picker once `selected` becomes null.
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    // Best-effort — stops this device from receiving this account's pushes
    // once signed out. Must run before logout clears the access token.
    await ref.read(pushNotificationServiceProvider).unregister(
          repository: ref.read(notificationsRepositoryProvider),
          secureStorage: ref.read(secureStorageProvider),
        );
    await ref.read(workspaceNotifierProvider.notifier).clearSelection();
    await ref.read(authNotifierProvider.notifier).logout();
    // Router redirect (app.dart) sends the user back to Login.
  }
}

/// Picker between the three app-wide visual skins: Classic, "Game Leon"
/// (Mục 16.2), and Tối (professional dark mode).
class _VisualStyleSection extends ConsumerWidget {
  const _VisualStyleSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(visualStyleProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Giao diện', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary, fontSize: 12)),
        ),
        Row(
          children: [
            Expanded(
              child: _StyleOptionCard(
                title: 'Cổ điển',
                subtitle: 'Gọn gàng, chuyên nghiệp',
                icon: Icons.receipt_long_rounded,
                accent: AppColors.primary,
                surface: AppColors.surface,
                border: AppColors.divider,
                textColor: AppColors.textPrimary,
                subtitleColor: AppColors.textSecondary,
                selected: current == AppVisualStyle.classic,
                onTap: () => ref.read(visualStyleProvider.notifier).setStyle(AppVisualStyle.classic),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StyleOptionCard(
                title: 'Tối',
                subtitle: 'Nền tối, chuyên nghiệp',
                icon: Icons.dark_mode_rounded,
                accent: DarkColors.primary,
                surface: DarkColors.surface,
                border: DarkColors.divider,
                textColor: DarkColors.textPrimary,
                subtitleColor: DarkColors.textSecondary,
                selected: current == AppVisualStyle.dark,
                onTap: () => ref.read(visualStyleProvider.notifier).setStyle(AppVisualStyle.dark),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StyleOptionCard(
                title: 'Game Leon',
                subtitle: 'Vui nhộn cùng Leon',
                icon: Icons.emoji_events_rounded,
                accent: GameColors.gold,
                surface: GameColors.surface,
                border: GameColors.surfaceBorder,
                textColor: Colors.white,
                subtitleColor: Colors.white70,
                selected: current == AppVisualStyle.gameLeon,
                onTap: () => ref.read(visualStyleProvider.notifier).setStyle(AppVisualStyle.gameLeon),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StyleOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Color surface;
  final Color border;
  final Color textColor;
  final Color subtitleColor;
  final bool selected;
  final VoidCallback onTap;

  const _StyleOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.surface,
    required this.border,
    required this.textColor,
    required this.subtitleColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? accent : border, width: selected ? 2 : 1),
          boxShadow: selected
              ? [BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 4))]
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: 0.18)),
                  alignment: Alignment.center,
                  child: Icon(icon, color: accent, size: 15),
                ),
                const Spacer(),
                if (selected) Icon(Icons.check_circle, color: accent, size: 16),
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: textColor)),
            const SizedBox(height: 2),
            Text(subtitle, maxLines: 2, style: TextStyle(fontSize: 10, color: subtitleColor, height: 1.25)),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final ScreenNeutrals neutrals;

  const _SectionCard({required this.title, required this.children, required this.neutrals});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: neutrals.textSecondary, fontSize: 12)),
        ),
        Container(
          decoration: neutrals.cardDecoration(radius: 14),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final VoidCallback? onTap;
  final bool showChevron;
  final ScreenNeutrals neutrals;

  const _SettingsTile({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.titleColor,
    this.onTap,
    this.showChevron = false,
    required this.neutrals,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(radius: 18, backgroundColor: color.withValues(alpha: 0.12), child: Icon(icon, color: color, size: 18)),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: titleColor ?? neutrals.textPrimary)),
      subtitle: subtitle != null ? Text(subtitle!, style: TextStyle(color: neutrals.textSecondary)) : null,
      trailing: showChevron ? Icon(Icons.chevron_right, color: neutrals.textSecondary) : null,
    );
  }
}
