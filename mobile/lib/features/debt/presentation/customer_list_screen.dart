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
import '../data/supplier_repository.dart';
import '../domain/customer.dart';
import 'create_customer_sheet.dart';
import 'create_supplier_sheet.dart';
import 'customer_detail_screen.dart';
import 'supplier_detail_screen.dart';

enum _DebtFilter { all, owing, overdue }

const _supplierColor = Color(0xFFE65100);

/// Tab Công nợ: "Phải thu" (khách hàng nợ mình) và "Phải trả" (mình nợ NCC).
class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  _DebtFilter _receivableFilter = _DebtFilter.all;
  _DebtFilter _payableFilter = _DebtFilter.all;
  String _receivableSearch = '';
  String _payableSearch = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = ref.watch(visualStyleProvider);
    final n = neutralsFor(style);
    final accent = sectionAccent(AppSection.debt, style);
    final isPayableTab = _tabController.index == 1;

    return Scaffold(
      backgroundColor: n.tint(isPayableTab ? _supplierColor : accent),
      appBar: SectionAppBar(
        title: 'Công nợ',
        style: style,
        actions: [
          IconButton(
            tooltip: 'Xuất Excel',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final customers = ref.read(customerListProvider).valueOrNull;
              if (customers == null || customers.isEmpty) {
                messenger.showSnackBar(const SnackBar(content: Text('Không có khách hàng để xuất')));
                return;
              }
              try {
                final path = await excelExportService.exportCustomers(customers: customers);
                messenger.showSnackBar(SnackBar(
                  content: Text('Đã lưu file Excel vào $path'),
                  duration: const Duration(seconds: 5),
                ));
              } catch (_) {
                messenger.showSnackBar(const SnackBar(content: Text('Không thể xuất file Excel')));
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: n.surface,
            child: TabBar(
              controller: _tabController,
              labelColor: isPayableTab ? _supplierColor : accent,
              unselectedLabelColor: n.textSecondary,
              indicatorColor: isPayableTab ? _supplierColor : accent,
              tabs: const [
                Tab(icon: Icon(Icons.arrow_circle_down_outlined, size: 18), text: 'Phải thu'),
                Tab(icon: Icon(Icons.arrow_circle_up_outlined, size: 18), text: 'Phải trả'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ReceivableTab(
                  filter: _receivableFilter,
                  searchText: _receivableSearch,
                  onFilterChanged: (f) => setState(() => _receivableFilter = f),
                  onSearchChanged: (s) => setState(() => _receivableSearch = s),
                  n: n,
                  accent: accent,
                ),
                _PayableTab(
                  filter: _payableFilter,
                  searchText: _payableSearch,
                  onFilterChanged: (f) => setState(() => _payableFilter = f),
                  onSearchChanged: (s) => setState(() => _payableSearch = s),
                  n: n,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: isPayableTab
          ? FloatingActionButton.extended(
              backgroundColor: _supplierColor,
              foregroundColor: Colors.white,
              onPressed: () => showCreateSupplierSheet(context),
              icon: const Icon(Icons.store_outlined),
              label: const Text('Thêm NCC'),
            )
          : FloatingActionButton.extended(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              onPressed: () => showCreateCustomerSheet(context),
              icon: const Icon(Icons.person_add),
              label: const Text('Thêm khách'),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab Phải thu (receivable) — customers
// ---------------------------------------------------------------------------

class _ReceivableTab extends ConsumerStatefulWidget {
  final _DebtFilter filter;
  final String searchText;
  final ValueChanged<_DebtFilter> onFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final ScreenNeutrals n;
  final Color accent;

  const _ReceivableTab({
    required this.filter,
    required this.searchText,
    required this.onFilterChanged,
    required this.onSearchChanged,
    required this.n,
    required this.accent,
  });

  @override
  ConsumerState<_ReceivableTab> createState() => _ReceivableTabState();
}

class _ReceivableTabState extends ConsumerState<_ReceivableTab> {
  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customerListProvider);
    final n = widget.n;
    final accent = widget.accent;

    return Column(
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
            onChanged: (value) => widget.onSearchChanged(value.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: customersAsync.when(
            loading: () => Center(child: CircularProgressIndicator(color: n.isGame ? accent : null)),
            error: (_, __) => Center(child: Text('Không thể tải danh sách', style: TextStyle(color: n.textPrimary))),
            data: (customers) {
              final owing = customers.where((c) => c.debtBalance > 0).toList();
              final totalDebt = customers.fold<num>(0, (s, c) => s + c.debtBalance);
              final filtered = customers.where((c) {
                if (widget.filter != _DebtFilter.all && c.debtBalance <= 0) return false;
                if (widget.searchText.isEmpty) return true;
                return c.name.toLowerCase().contains(widget.searchText) || (c.phone ?? '').contains(widget.searchText);
              }).toList();

              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(customerListProvider),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        _FilterChip(label: 'Tất cả', count: customers.length, selected: widget.filter == _DebtFilter.all, neutrals: n, accent: accent, onTap: () => widget.onFilterChanged(_DebtFilter.all)),
                        const SizedBox(width: 8),
                        _FilterChip(label: 'Đang nợ', count: owing.length, selected: widget.filter == _DebtFilter.owing, neutrals: n, accent: accent, onTap: () => widget.onFilterChanged(_DebtFilter.owing)),
                        const SizedBox(width: 8),
                        _FilterChip(label: 'Quá hạn', count: 0, selected: widget.filter == _DebtFilter.overdue, neutrals: n, accent: accent, onTap: () => widget.onFilterChanged(_DebtFilter.overdue)),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: n.cardDecoration(),
                      child: Row(children: [
                        Expanded(child: _SummaryStat(label: 'Tổng phải thu', amount: totalDebt, color: AppColors.expense, neutrals: n)),
                        Container(width: 1, height: 32, color: n.divider),
                        Expanded(child: _SummaryStat(label: 'Đang nợ', amount: owing.fold(0, (s, c) => s + c.debtBalance), color: n.textPrimary, neutrals: n)),
                        Container(width: 1, height: 32, color: n.divider),
                        Expanded(child: _SummaryStat(label: 'Quá hạn', amount: 0, color: n.textSecondary, neutrals: n)),
                      ]),
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
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CustomerDetailScreen(customer: c))),
                          )),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab Phải trả (payable) — suppliers
// ---------------------------------------------------------------------------

class _PayableTab extends ConsumerStatefulWidget {
  final _DebtFilter filter;
  final String searchText;
  final ValueChanged<_DebtFilter> onFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final ScreenNeutrals n;

  const _PayableTab({
    required this.filter,
    required this.searchText,
    required this.onFilterChanged,
    required this.onSearchChanged,
    required this.n,
  });

  @override
  ConsumerState<_PayableTab> createState() => _PayableTabState();
}

class _PayableTabState extends ConsumerState<_PayableTab> {
  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(supplierListProvider);
    final n = widget.n;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            style: TextStyle(color: n.textPrimary),
            decoration: InputDecoration(
              hintText: 'Tìm nhà cung cấp, SĐT...',
              hintStyle: TextStyle(color: n.textSecondary),
              prefixIcon: Icon(Icons.search, color: n.textSecondary),
              filled: true,
              fillColor: n.isGame ? n.surface : n.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              isDense: true,
            ),
            onChanged: (value) => widget.onSearchChanged(value.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: suppliersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(child: Text('Không thể tải danh sách NCC', style: TextStyle(color: n.textPrimary))),
            data: (suppliers) {
              final owing = suppliers.where((s) => s.debtBalance > 0).toList();
              final totalPayable = owing.fold<num>(0, (s, c) => s + c.debtBalance);

              final filtered = suppliers.where((s) {
                if (widget.filter != _DebtFilter.all && s.debtBalance <= 0) return false;
                if (widget.searchText.isEmpty) return true;
                return s.name.toLowerCase().contains(widget.searchText) || (s.phone ?? '').contains(widget.searchText);
              }).toList();

              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(supplierListProvider),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        _FilterChip(label: 'Tất cả', count: suppliers.length, selected: widget.filter == _DebtFilter.all, neutrals: n, accent: _supplierColor, onTap: () => widget.onFilterChanged(_DebtFilter.all)),
                        const SizedBox(width: 8),
                        _FilterChip(label: 'Đang nợ', count: owing.length, selected: widget.filter == _DebtFilter.owing, neutrals: n, accent: _supplierColor, onTap: () => widget.onFilterChanged(_DebtFilter.owing)),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: n.cardDecoration(),
                      child: Row(children: [
                        Expanded(child: _SummaryStat(label: 'Tổng phải trả', amount: totalPayable, color: _supplierColor, neutrals: n)),
                        Container(width: 1, height: 32, color: n.divider),
                        Expanded(child: _SummaryStat(label: 'Số NCC nợ', amount: owing.length, color: n.textPrimary, neutrals: n, isCount: true)),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    if (suppliers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: EmptyStateWidget(
                          message: 'Chưa có nhà cung cấp nào.\nBấm "Thêm NCC" để bắt đầu theo dõi công nợ phải trả.',
                          icon: Icons.store_outlined,
                          accent: _supplierColor,
                        ),
                      )
                    else if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: EmptyStateWidget(message: 'Không có kết quả.', icon: Icons.search_off, accent: _supplierColor),
                      )
                    else
                      ...filtered.map((s) => _SupplierTile(
                            supplier: s,
                            neutrals: n,
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SupplierDetailScreen(supplier: s))),
                          )),
                  ],
                ),
              );
            },
          ),
        ),
      ],
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
  final bool isCount;

  const _SummaryStat({required this.label, required this.amount, required this.color, required this.neutrals, this.isCount = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          isCount ? amount.toInt().toString() : formatVND(amount),
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

class _SupplierTile extends StatelessWidget {
  final Customer supplier;
  final VoidCallback onTap;
  final ScreenNeutrals neutrals;

  const _SupplierTile({required this.supplier, required this.onTap, required this.neutrals});

  @override
  Widget build(BuildContext context) {
    final owes = supplier.debtBalance > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: neutrals.cardDecoration(radius: 12),
      child: ListTile(
        onTap: onTap,
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            InitialsAvatar(name: supplier.name),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: _supplierColor, shape: BoxShape.circle),
                child: const Icon(Icons.store, size: 10, color: Colors.white),
              ),
            ),
          ],
        ),
        title: Text(supplier.name, style: TextStyle(fontWeight: FontWeight.w600, color: neutrals.textPrimary)),
        subtitle: Text(supplier.phone ?? 'Nhà cung cấp', style: TextStyle(color: neutrals.textSecondary)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatVND(supplier.debtBalance),
              style: TextStyle(fontWeight: FontWeight.bold, color: owes ? _supplierColor : AppColors.income),
            ),
            Text(owes ? 'Bạn đang nợ' : 'Đã tất toán', style: TextStyle(fontSize: 10, color: owes ? _supplierColor : AppColors.income)),
          ],
        ),
      ),
    );
  }
}
