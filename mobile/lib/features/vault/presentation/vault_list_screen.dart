import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/section_app_bar.dart';
import '../data/vault_repository.dart';
import '../domain/vault.dart';
import 'create_vault_sheet.dart';
import 'reconcile_sheet.dart';
import 'vault_detail_screen.dart';

IconData vaultTypeIcon(VaultType type) {
  switch (type) {
    case VaultType.bank:
      return Icons.account_balance;
    case VaultType.ewallet:
      return Icons.smartphone;
    case VaultType.cash:
      return Icons.payments;
  }
}

class VaultListScreen extends ConsumerWidget {
  const VaultListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vaultsAsync = ref.watch(vaultListProvider);

    return Scaffold(
      backgroundColor: AppColors.tint(AppColors.secondary),
      appBar: const SectionAppBar(title: 'Túi tiền', accent: AppColors.secondary),
      body: vaultsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => const Center(child: Text('Không thể tải danh sách túi tiền')),
        data: (vaults) {
          if (vaults.isEmpty) {
            return const EmptyStateWidget(
              message: 'Chưa có túi tiền nào.\nThêm túi tiền để bắt đầu quản lý dòng tiền.',
              icon: Icons.account_balance_wallet_outlined,
            );
          }
          final total = vaults.fold<num>(0, (s, v) => s + v.currentBalance);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(vaultListProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: AppColors.heroGradient(AppColors.secondary), begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tổng số dư các túi', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 6),
                      Text(formatVND(total), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...vaults.map((vault) => _VaultTile(vault: vault)),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        onPressed: () async {
          final created = await showCreateVaultSheet(context);
          if (created == true) {
            ref.invalidate(vaultListProvider);
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Thêm túi'),
      ),
    );
  }
}

class _VaultTile extends ConsumerWidget {
  final Vault vault;

  const _VaultTile({required this.vault});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = AppColors.forKey(vault.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => VaultDetailScreen(vault: vault))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(radius: 20, backgroundColor: color.withValues(alpha: 0.12), child: Icon(vaultTypeIcon(vault.type), color: color)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(vault.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(vaultTypeLabel(vault.type), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatVND(vault.currentBalance), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 2),
                  TextButton(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 24), visualDensity: VisualDensity.compact),
                    onPressed: () async {
                      final done = await showReconcileFlow(context, ref);
                      if (done == true) ref.invalidate(vaultListProvider);
                    },
                    child: const Text('Kiểm kê', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
