import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/export/excel_export_service.dart';
import '../../../core/theme/screen_neutrals.dart';
import '../../../core/theme/section_accents.dart';
import '../../../core/theme/visual_style_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/initials_avatar.dart';
import '../../../shared/widgets/section_app_bar.dart';
import '../data/customer_repository.dart';
import '../domain/customer.dart';
import 'create_customer_sheet.dart';
import 'customer_detail_screen.dart';

enum _DebtFilter { all, owing, overdue }

/// Tab Công nợ (Mục 12.10). Overdue tracking (`hạn trả`) is not yet exposed
/// by the backend contract for this pass, so the "Quá hạn" segment
/// currently behaves the same as "Đang nợ" (customers with balance > 0) —
/// documented simplification, to be wired up once the API returns a due
/// date / overdue flag.
class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  _DebtFilter _filter = _DebtFilter.all;
  String _searchText = '';

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customerListProvider);
    final style = ref.watch(visualStyleProvider);
    final n = neutralsFor(style);
    final accent = sectionAccent(AppSection.debt, style);

    return Scaffold(
      backgroundColor: n.tint(accent),
      appBar: SectionAppBar(
        title: 'Công nợ',
        style: style,
        actions: [
          IconButton(
            tooltip: 'Xuất Excel',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () async {
              final customers = customersAsync.valueOrNull;
              if (customers == null || customers.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không có khách hàng để xuất')));
                return;
              }
              await excelExportService.exportCustomers(customers: customers);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              style: TextStyle(color: n.textPrimary),
              decoration: InputDecoration(
                hintText: 'Tìm khách hàng, SĐT...',
                hintStyle: TextStyle(color: n.textSecondary),
                prefixIcon: Icon(Icons.search, color: n.textSecondary),
                filled: true,
                fillColor: n.isGame ? n.surface : n.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _searchText = value.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: customersAsync.when(
              loading: () => Center(child: CircularProgressIndicator(color: n.isGame ? accent : null)),
              error: (error, _) => Center(child: Text('Không thể tải danh sách khách hàng', style: TextStyle(color: n.textPrimary))),
              data: (customers) {
                final owing = customers.where((c) => c.debtBalance > 0).toList();
                final totalDebt = customers.fold<num>(0, (s, c) => s + c.debtBalance);

                var filtered = customers.where((c) {
                  if (_filter != _DebtFilter.all && c.debtBalance <= 0) return false;
                  if (_searchText.isEmpty) return true;
                  return c.name.toLowerCase().contains(_searchText) || (c.phone ?? '').contains(_searchText);
                }).toList();

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(customerListProvider),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _FilterChip(
                              label: 'Tất cả',
                              count: customers.length,
                              selected: _filter == _DebtFilter.all,
                              neutrals: n,
                              accent: accent,
                              onTap: () => setState(() => _filter = _DebtFilter.all),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'Đang nợ',
                              count: owing.length,
                              selected: _filter == _DebtFilter.owing,
                              neutrals: n,
                              accent: accent,
                              onTap: () => setState(() => _filter = _DebtFilter.owing),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'Quá hạn',
                              count: 0,
                              selected: _filter == _DebtFilter.overdue,
                              neutrals: n,
                              accent: accent,
                              onTap: () => setState(() => _filter = _DebtFilter.overdue),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: n.cardDecoration(),
                        child: Row(
                          children: [
                            Expanded(child: _SummaryStat(label: 'Tổng nợ', amount: totalDebt, color: AppColors.expense, neutrals: n)),
                            Container(width: 1, height: 32, color: n.divider),
                            Expanded(child: _SummaryStat(label: 'Đang nợ', amount: totalDebt, color: n.textPrimary, neutrals: n)),
                            Container(width: 1, height: 32, color: n.divider),
                            Expanded(child: _SummaryStat(label: 'Quá hạn', amount: 0, color: n.textSecondary, neutrals: n)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: EmptyStateWidget(message: 'Chưa có khách hàng nào.', icon: Icons.people_outline, accent: accent),
                        )
                      else
                        ...filtered.map((c) => _CustomerTile(
                              customer: c,
                              neutrals: n,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => CustomerDetailScreen(customer: c)),
                                );
                              },
                            )),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        onPressed: () => showCreateCustomerSheet(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Thêm khách'),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final ScreenNeutrals neutrals;
  final Color accent;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.count, required this.selected, required this.neutrals, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accent : neutrals.surface,
          borderRadius: BorderRadius.circular(20),
          border: !selected && neutrals.isGame ? Border.all(color: neutrals.divider) : null,
        ),
        child: Text(
          '$label $count',
          style: TextStyle(
            color: selected ? Colors.white : neutrals.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final num amount;
  final Color color;
  final ScreenNeutrals neutrals;

  const _SummaryStat({required this.label, required this.amount, required this.color, required this.neutrals});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          formatVND(amount),
          style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: neutrals.textSecondary)),
      ],
    );
  }
}

class _CustomerTile extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;
  final ScreenNeutrals neutrals;

  const _CustomerTile({required this.customer, required this.onTap, required this.neutrals});

  @override
  Widget build(BuildContext context) {
    final owesMoney = customer.debtBalance > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: neutrals.cardDecoration(radius: 12),
      child: ListTile(
        onTap: onTap,
        leading: InitialsAvatar(name: customer.name),
        title: Text(customer.name, style: TextStyle(fontWeight: FontWeight.w600, color: neutrals.textPrimary)),
        subtitle: Text(customer.phone ?? '', style: TextStyle(color: neutrals.textSecondary)),
        trailing: Text(
          formatVND(customer.debtBalance),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: owesMoney ? AppColors.expense : neutrals.textSecondary,
          ),
        ),
      ),
    );
  }
}
