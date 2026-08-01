import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/export/excel_export_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/initials_avatar.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Công nợ'),
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
              decoration: InputDecoration(
                hintText: 'Tìm khách hàng, SĐT...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _searchText = value.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: customersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => const Center(child: Text('Không thể tải danh sách khách hàng')),
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
                              onTap: () => setState(() => _filter = _DebtFilter.all),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'Đang nợ',
                              count: owing.length,
                              selected: _filter == _DebtFilter.owing,
                              onTap: () => setState(() => _filter = _DebtFilter.owing),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'Quá hạn',
                              count: 0,
                              selected: _filter == _DebtFilter.overdue,
                              onTap: () => setState(() => _filter = _DebtFilter.overdue),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: Row(
                          children: [
                            Expanded(child: _SummaryStat(label: 'Tổng nợ', amount: totalDebt, color: AppColors.expense)),
                            Container(width: 1, height: 32, color: AppColors.divider),
                            Expanded(child: _SummaryStat(label: 'Đang nợ', amount: totalDebt, color: AppColors.textPrimary)),
                            Container(width: 1, height: 32, color: AppColors.divider),
                            const Expanded(child: _SummaryStat(label: 'Quá hạn', amount: 0, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (filtered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: EmptyStateWidget(message: 'Chưa có khách hàng nào.', icon: Icons.people_outline),
                        )
                      else
                        ...filtered.map((c) => _CustomerTile(
                              customer: c,
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
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.count, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '$label $count',
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textPrimary,
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

  const _SummaryStat({required this.label, required this.amount, required this.color});

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
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _CustomerTile extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;

  const _CustomerTile({required this.customer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final owesMoney = customer.debtBalance > 0;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppColors.surface,
      child: ListTile(
        onTap: onTap,
        leading: InitialsAvatar(name: customer.name),
        title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(customer.phone ?? ''),
        trailing: Text(
          formatVND(customer.debtBalance),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: owesMoney ? AppColors.expense : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
