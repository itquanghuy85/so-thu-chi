import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/game_colors.dart';
import '../../../core/offline/sync_queue_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/game/game_widgets.dart';
import '../../../shared/widgets/leon_mascot.dart';
import '../../budget/data/budget_repository.dart';
import '../../budget/presentation/budget_management_screen.dart';
import '../../gamification/data/gamification_repository.dart';
import '../../transaction/presentation/create_transaction_sheet.dart';
import '../../transaction/presentation/transaction_display.dart';
import '../../transaction/domain/transaction.dart';
import '../../vault/domain/vault.dart';
import '../../vault/presentation/reconcile_sheet.dart';
import '../../vault/presentation/vault_detail_screen.dart';
import '../../voice/presentation/voice_input_sheet.dart';
import 'dashboard_notifier.dart';

String _gameGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 11) return 'Chào buổi sáng, chủ shop!';
  if (hour < 18) return 'Chiều nay bán thế nào?';
  return 'Tổng kết một ngày nào!';
}

/// The "Game Leon" skin for the Dashboard (Mục 16.2) — same underlying
/// [DashboardData] the Classic dashboard renders, just presented as a dark
/// arcade panel with Leon the mascot instead of a plain finance-app card.
class GameDashboardBody extends ConsumerWidget {
  final DashboardData data;
  final String userName;
  final bool balanceHidden;
  final VoidCallback onToggleBalance;

  const GameDashboardBody({
    super.key,
    required this.data,
    required this.userName,
    required this.balanceHidden,
    required this.onToggleBalance,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(gamificationProfileProvider);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: GameColors.bgGradient, begin: Alignment.topCenter, end: Alignment.bottomCenter),
      ),
      child: RefreshIndicator(
        color: GameColors.cyan,
        backgroundColor: GameColors.surface,
        onRefresh: () async {
          ref.invalidate(dashboardDataProvider);
          ref.invalidate(gamificationProfileProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            SafeArea(
              bottom: false,
              child: profileAsync.when(
                loading: () => const _GameHero(level: 1, xpLabel: '', progress: 0, userName: ''),
                error: (_, _) => const _GameHero(level: 1, xpLabel: '', progress: 0, userName: ''),
                data: (profile) => _GameHero(
                  level: profile.level,
                  xpLabel: '${profile.xp} / ${profile.xpNextLevel} XP',
                  progress: profile.levelProgress,
                  userName: userName,
                ),
              ),
            ),
            const SizedBox(height: 18),
            GameCard(
              borderColor: GameColors.gold.withValues(alpha: 0.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.savings_rounded, color: GameColors.gold, size: 16),
                      const SizedBox(width: 6),
                      const Text('Kho báu tổng', style: TextStyle(color: GameColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      InkWell(
                        onTap: onToggleBalance,
                        child: Icon(balanceHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: GameColors.textSecondary, size: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    balanceHidden ? '••••••••' : formatVND(data.totalBalance),
                    style: const TextStyle(
                      color: GameColors.gold,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(color: GameColors.gold, blurRadius: 16)],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _GameStat(label: 'Thu hôm nay', amount: data.todayIncome, color: GameColors.lime, icon: Icons.arrow_downward_rounded)),
                const SizedBox(width: 10),
                Expanded(child: _GameStat(label: 'Chi hôm nay', amount: data.todayExpense, color: GameColors.coral, icon: Icons.arrow_upward_rounded)),
              ],
            ),
            const _GameBudgetWarningBanner(),
            const SizedBox(height: 20),
            const GameSectionHeader(title: 'Rương báu (Túi tiền)'),
            const SizedBox(height: 10),
            _GameVaultRow(vaults: data.vaults),
            const SizedBox(height: 24),
            const GameSectionHeader(title: 'Hành động nhanh'),
            const SizedBox(height: 12),
            _GameQuickActions(
              onCreated: () {
                ref.invalidate(dashboardDataProvider);
                ref.invalidate(gamificationProfileProvider);
                ref.invalidate(pendingSyncCountProvider);
              },
            ),
            const SizedBox(height: 24),
            GameSectionHeader(
              title: 'Nhật ký nhiệm vụ',
              trailing: TextButton(
                onPressed: () => context.go('/transactions'),
                style: TextButton.styleFrom(foregroundColor: GameColors.cyan),
                child: const Text('Xem tất cả'),
              ),
            ),
            const SizedBox(height: 8),
            if (data.recentTransactions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Chưa có giao dịch nào', style: TextStyle(color: GameColors.textSecondary)),
              )
            else
              ...data.recentTransactions.map((t) => _GameQuestLogTile(transaction: t)),
          ],
        ),
      ),
    );
  }
}

class _GameHero extends StatelessWidget {
  final int level;
  final String xpLabel;
  final double progress;
  final String userName;

  const _GameHero({required this.level, required this.xpLabel, required this.progress, required this.userName});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(50),
          onTap: () => context.push('/gamification'),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              LeonMascot(size: 84, mood: progress > 0.8 ? LeonMood.proud : LeonMood.happy, crowned: level >= 5),
              Positioned(bottom: -6, right: -6, child: GameLevelBadge(level: level, size: 34)),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_gameGreeting(), style: const TextStyle(color: GameColors.textSecondary, fontSize: 12)),
              Text(
                userName.isEmpty ? 'Nhà vô địch' : userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: GameColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              if (xpLabel.isNotEmpty) GameXpBar(progress: progress, label: xpLabel),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Cài đặt',
          icon: const Icon(Icons.settings_outlined, color: GameColors.textPrimary),
          onPressed: () => context.push('/settings'),
        ),
      ],
    );
  }
}

class _GameStat extends StatelessWidget {
  final String label;
  final num amount;
  final Color color;
  final IconData icon;

  const _GameStat({required this.label, required this.amount, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return GameCard(
      borderColor: color.withValues(alpha: 0.4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(
            formatVND(amount),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: GameColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

/// Game-skin counterpart to the Classic dashboard's budget banner — same
/// data source ([budgetListProvider]), styled as a warning quest-log entry.
class _GameBudgetWarningBanner extends ConsumerWidget {
  const _GameBudgetWarningBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetListProvider);
    return budgetsAsync.maybeWhen(
      data: (budgets) {
        final flagged = budgets.where((b) => b.progress >= 0.8).toList()..sort((a, b) => b.progress.compareTo(a.progress));
        if (flagged.isEmpty) return const SizedBox.shrink();
        final worst = flagged.first;
        final color = worst.overBudget ? GameColors.coral : GameColors.gold;
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BudgetManagementScreen())),
            child: GameCard(
              borderColor: color.withValues(alpha: 0.5),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: color, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          worst.overBudget
                              ? '${worst.categoryName ?? 'Tổng chi tiêu'} đã vượt ngân sách!'
                              : '${worst.categoryName ?? 'Tổng chi tiêu'} sắp đạt hạn mức',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: color),
                        ),
                        if (flagged.length > 1)
                          Text(
                            'Và ${flagged.length - 1} ngân sách khác cần chú ý',
                            style: const TextStyle(fontSize: 11, color: GameColors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: color, size: 18),
                ],
              ),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _GameVaultRow extends StatelessWidget {
  final List<Vault> vaults;

  const _GameVaultRow({required this.vaults});

  @override
  Widget build(BuildContext context) {
    if (vaults.isEmpty) {
      return GameCard(
        child: const Text('Chưa có rương báu nào. Thêm túi tiền trong tab Túi tiền.', style: TextStyle(color: GameColors.textSecondary)),
      );
    }
    final maxBalance = vaults.fold<num>(1, (m, v) => v.currentBalance > m ? v.currentBalance : m);
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: vaults.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final vault = vaults[index];
          final progress = (vault.currentBalance / maxBalance).toDouble();
          return GameChestCard(
            name: vault.name,
            balanceLabel: formatVND(vault.currentBalance),
            progress: progress,
            accent: GameColors.forKey(vault.id),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => VaultDetailScreen(vault: vault))),
          );
        },
      ),
    );
  }
}

class _GameQuickActions extends StatelessWidget {
  final VoidCallback onCreated;

  const _GameQuickActions({required this.onCreated});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          GameActionButton(
            label: 'Thu',
            icon: Icons.add,
            color: GameColors.lime,
            onTap: () async {
              final created = await showCreateTransactionSheet(context, initialTabIndex: 0);
              if (created == true) onCreated();
            },
          ),
          GameActionButton(
            label: 'Chi',
            icon: Icons.remove,
            color: GameColors.coral,
            onTap: () async {
              final created = await showCreateTransactionSheet(context, initialTabIndex: 1);
              if (created == true) onCreated();
            },
          ),
          GameActionButton(
            label: 'Chuyển',
            icon: Icons.swap_horiz,
            color: GameColors.gold,
            onTap: () async {
              final created = await showCreateTransactionSheet(context, initialTabIndex: 2);
              if (created == true) onCreated();
            },
          ),
          GameActionButton(
            label: 'Kiểm kê',
            icon: Icons.fact_check_outlined,
            color: GameColors.cyan,
            onTap: () async {
              final done = await showReconcileFlow(context, ref);
              if (done == true) onCreated();
            },
          ),
          GameActionButton(
            label: 'Nói',
            icon: Icons.mic_none_rounded,
            color: GameColors.violet,
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

class _GameQuestLogTile extends StatelessWidget {
  final Transaction transaction;

  const _GameQuestLogTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final color = transactionColor(transaction.type);
    final isVoided = transaction.isVoided;
    return Opacity(
      opacity: isVoided ? 0.4 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: GameColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: ListTile(
          dense: true,
          leading: Icon(transactionIcon(transaction.type), color: color, size: 20),
          title: Text(
            transactionTypeLabel(transaction.type) + (isVoided ? ' (đã hủy)' : ''),
            style: const TextStyle(color: GameColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
          ),
          subtitle: Text(
            transactionDescription(transaction),
            style: const TextStyle(color: GameColors.textSecondary, fontSize: 11),
          ),
          trailing: Text(
            '${transactionAmountSign(transaction.type)}${formatVND(transaction.amount)}',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ),
    );
  }
}
