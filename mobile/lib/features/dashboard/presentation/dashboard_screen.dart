import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/offline/sync_queue_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/providers/current_workspace_provider.dart';
import '../../../shared/widgets/initials_avatar.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../gamification/data/gamification_repository.dart';
import '../../transaction/presentation/create_transaction_sheet.dart';
import '../../transaction/presentation/transaction_list_screen.dart';
import '../../vault/domain/vault.dart';
import '../../vault/presentation/reconcile_sheet.dart';
import '../../vault/presentation/vault_detail_screen.dart';
import '../../vault/presentation/vault_list_screen.dart';
import '../../voice/presentation/voice_input_sheet.dart';
import 'dashboard_notifier.dart';

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 11) return 'Chào buổi sáng!';
  if (hour < 18) return 'Chào buổi chiều!';
  return 'Chào buổi tối!';
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _balanceHidden = false;

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(currentWorkspaceProvider);
    final user = ref.watch(authNotifierProvider).user;
    final dashboardAsync = ref.watch(dashboardDataProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Không thể tải dữ liệu tổng quan.', textAlign: TextAlign.center),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => ref.invalidate(dashboardDataProvider),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(dashboardDataProvider),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _HeaderCard(
                userName: user?.fullName ?? workspace?.name ?? '',
                workspaceName: workspace?.name ?? 'Sổ Thu Chi',
                totalBalance: data.totalBalance,
                todayNet: data.todayNet,
                hidden: _balanceHidden,
                onToggleHidden: () => setState(() => _balanceHidden = !_balanceHidden),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TodayCashflowRow(income: data.todayIncome, expense: data.todayExpense),
                    const SizedBox(height: 20),
                    _VaultCarousel(vaults: data.vaults),
                    const SizedBox(height: 20),
                    _QuickActionsRow(
                      onCreated: () {
                        ref.invalidate(dashboardDataProvider);
                        // New transactions/reconciles can award XP or unlock
                        // achievements — refresh the header badge too.
                        ref.invalidate(gamificationProfileProvider);
                        ref.invalidate(pendingSyncCountProvider);
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Giao dịch gần đây', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        TextButton(
                          onPressed: () => context.go('/transactions'),
                          child: const Text('Xem tất cả'),
                        ),
                      ],
                    ),
                    if (data.recentTransactions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('Chưa có giao dịch nào', style: TextStyle(color: AppColors.textSecondary)),
                      )
                    else
                      ...data.recentTransactions.map(
                        (t) => TransactionTile(transaction: t, onTap: null),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String userName;
  final String workspaceName;
  final num totalBalance;
  final num todayNet;
  final bool hidden;
  final VoidCallback onToggleHidden;

  const _HeaderCard({
    required this.userName,
    required this.workspaceName,
    required this.totalBalance,
    required this.todayNet,
    required this.hidden,
    required this.onToggleHidden,
  });

  @override
  Widget build(BuildContext context) {
    // Real day-over-day change, derived from today's net cashflow against
    // the implied balance before today's transactions — not a fabricated
    // number.
    final balanceBeforeToday = totalBalance - todayNet;
    final changePercent = balanceBeforeToday.abs() < 1 ? null : (todayNet / balanceBeforeToday) * 100;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.headerGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InitialsAvatar(name: userName.isEmpty ? workspaceName : userName, radius: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_greeting(), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      Text(
                        userName.isEmpty ? workspaceName : userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const _XpBadge(),
                IconButton(
                  tooltip: 'Cài đặt',
                  icon: const Icon(Icons.settings_outlined, color: Colors.white),
                  onPressed: () => context.push('/settings'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text('Tổng tài sản', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(width: 6),
                InkWell(
                  onTap: onToggleHidden,
                  borderRadius: BorderRadius.circular(20),
                  child: Icon(hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: Colors.white70, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              hidden ? '••••••••' : formatVND(totalBalance),
              style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
            ),
            if (changePercent != null && !hidden) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(changePercent >= 0 ? Icons.arrow_upward : Icons.arrow_downward, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      '${changePercent.abs().toStringAsFixed(1)}% so với hôm qua',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TodayCashflowRow extends StatelessWidget {
  final num income;
  final num expense;

  const _TodayCashflowRow({required this.income, required this.expense});

  @override
  Widget build(BuildContext context) {
    final net = income - expense;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Expanded(child: _CashflowStat(label: 'Thu', sub: 'Hôm nay', amount: income, color: AppColors.income, icon: Icons.arrow_downward)),
          Container(width: 1, height: 40, color: AppColors.divider),
          Expanded(child: _CashflowStat(label: 'Chi', sub: 'Hôm nay', amount: expense, color: AppColors.expense, icon: Icons.arrow_upward)),
          Container(width: 1, height: 40, color: AppColors.divider),
          Expanded(
            child: _CashflowStat(
              label: 'Thuần',
              sub: 'Hôm nay',
              amount: net,
              color: net >= 0 ? AppColors.income : AppColors.expense,
              icon: Icons.swap_vert,
            ),
          ),
        ],
      ),
    );
  }
}

class _CashflowStat extends StatelessWidget {
  final String label;
  final String sub;
  final num amount;
  final Color color;
  final IconData icon;

  const _CashflowStat({
    required this.label,
    required this.sub,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(radius: 14, backgroundColor: color.withValues(alpha: 0.12), child: Icon(icon, color: color, size: 15)),
        const SizedBox(height: 6),
        Text(
          formatVND(amount),
          style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text('$label $sub', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _VaultCarousel extends StatelessWidget {
  final List<Vault> vaults;

  const _VaultCarousel({required this.vaults});

  @override
  Widget build(BuildContext context) {
    if (vaults.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.divider)),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Chưa có túi tiền. Thêm túi tiền trong tab Túi tiền.'),
        ),
      );
    }
    final maxBalance = vaults.fold<num>(1, (m, v) => v.currentBalance > m ? v.currentBalance : m);
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: vaults.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final vault = vaults[index];
          final color = AppColors.forKey(vault.id);
          final progress = (vault.currentBalance / maxBalance).clamp(0.05, 1.0).toDouble();
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => VaultDetailScreen(vault: vault))),
            child: Container(
              width: 152,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(radius: 14, backgroundColor: color.withValues(alpha: 0.12), child: Icon(vaultTypeIcon(vault.type), color: color, size: 15)),
                  const Spacer(),
                  Text(vault.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(
                    formatVND(vault.currentBalance),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: color.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Compact "Lv.N" pill in the dashboard header — the app's only always-on
/// entry point into the gamification screen (Mục 9). Silently disappears on
/// error/loading instead of showing a spinner, since it's a secondary
/// affordance, not core dashboard content.
class _XpBadge extends ConsumerWidget {
  const _XpBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(gamificationProfileProvider);
    return profileAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (profile) => InkWell(
        onTap: () => context.push('/gamification'),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events_rounded, color: Colors.amberAccent, size: 14),
              const SizedBox(width: 4),
              Text('Lv.${profile.level}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  final VoidCallback onCreated;

  const _QuickActionsRow({required this.onCreated});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _QuickAction(
            label: 'Thu',
            icon: Icons.add,
            color: AppColors.income,
            onTap: () async {
              final created = await showCreateTransactionSheet(context, initialTabIndex: 0);
              if (created == true) onCreated();
            },
          ),
          _QuickAction(
            label: 'Chi',
            icon: Icons.remove,
            color: AppColors.expense,
            onTap: () async {
              final created = await showCreateTransactionSheet(context, initialTabIndex: 1);
              if (created == true) onCreated();
            },
          ),
          _QuickAction(
            label: 'Chuyển',
            icon: Icons.swap_horiz,
            color: AppColors.transfer,
            onTap: () async {
              final created = await showCreateTransactionSheet(context, initialTabIndex: 2);
              if (created == true) onCreated();
            },
          ),
          _QuickAction(
            label: 'Kiểm kê',
            icon: Icons.fact_check_outlined,
            color: AppColors.secondary,
            onTap: () async {
              final done = await showReconcileFlow(context, ref);
              if (done == true) onCreated();
            },
          ),
          _QuickAction(
            label: 'Nói',
            icon: Icons.mic_none_rounded,
            color: AppColors.debt,
            onTap: () async {
              final created = await showVoiceInputSheet(context);
              if (created == true) onCreated();
            },
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(32),
      child: Column(
        children: [
          CircleAvatar(radius: 24, backgroundColor: color, child: Icon(icon, color: Colors.white)),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
