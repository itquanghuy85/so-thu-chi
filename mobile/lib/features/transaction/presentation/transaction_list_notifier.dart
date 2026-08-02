import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../shared/providers/current_workspace_provider.dart';
import '../data/transaction_repository.dart';
import '../domain/transaction.dart';

enum TransactionPeriodFilter { all, today, week, month, custom }

extension TransactionPeriodFilterX on TransactionPeriodFilter {
  String get label => switch (this) {
        TransactionPeriodFilter.all => 'Tất cả',
        TransactionPeriodFilter.today => 'Hôm nay',
        TransactionPeriodFilter.week => 'Tuần',
        TransactionPeriodFilter.month => 'Tháng',
        TransactionPeriodFilter.custom => 'Tùy chọn',
      };

  DateTime? startDate(DateTime now) {
    switch (this) {
      case TransactionPeriodFilter.all:
      case TransactionPeriodFilter.custom: // handled via TransactionListFilter.customRange instead
        return null;
      case TransactionPeriodFilter.today:
        return DateTime(now.year, now.month, now.day);
      case TransactionPeriodFilter.week:
        final diffToMonday = now.weekday - DateTime.monday;
        final startOfDay = DateTime(now.year, now.month, now.day);
        return startOfDay.subtract(Duration(days: diffToMonday));
      case TransactionPeriodFilter.month:
        return DateTime(now.year, now.month, 1);
    }
  }
}

class TransactionListFilter {
  final TransactionPeriodFilter period;
  final TransactionType? type;
  final DateTimeRange? customRange;

  const TransactionListFilter({this.period = TransactionPeriodFilter.all, this.type, this.customRange});

  DateTime? get effectiveFromDate => period == TransactionPeriodFilter.custom ? customRange?.start : period.startDate(DateTime.now());

  /// Inclusive end-of-day for the custom range's end date; other periods
  /// run through "now" (no explicit `to_date`).
  DateTime? get effectiveToDate =>
      period == TransactionPeriodFilter.custom && customRange != null
          ? DateTime(customRange!.end.year, customRange!.end.month, customRange!.end.day, 23, 59, 59)
          : null;

  TransactionListFilter copyWith({
    TransactionPeriodFilter? period,
    TransactionType? type,
    bool clearType = false,
    DateTimeRange? customRange,
  }) {
    return TransactionListFilter(
      period: period ?? this.period,
      type: clearType ? null : (type ?? this.type),
      customRange: customRange ?? this.customRange,
    );
  }
}

class TransactionListState {
  final List<Transaction> items;
  final int page;
  final int totalPages;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;
  final TransactionListFilter filter;

  const TransactionListState({
    this.items = const [],
    this.page = 0,
    this.totalPages = 1,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.filter = const TransactionListFilter(),
  });

  bool get hasMore => page < totalPages;

  TransactionListState copyWith({
    List<Transaction>? items,
    int? page,
    int? totalPages,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
    TransactionListFilter? filter,
  }) {
    return TransactionListState(
      items: items ?? this.items,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      filter: filter ?? this.filter,
    );
  }
}

/// Drives the infinite-scroll Transactions tab: `GET
/// /transactions?...&page=&limit=20`, appending pages until
/// `page >= pagination.total_pages` (per spec Mục 12.4, applied uniformly
/// to all long lists in the app). Also owns the period/type filter bar —
/// `from_date` maps to the same period math used by the Reports tab.
class TransactionListNotifier extends StateNotifier<TransactionListState> {
  final TransactionRepository _repository;
  final String _workspaceId;

  TransactionListNotifier(this._repository, this._workspaceId) : super(const TransactionListState()) {
    loadFirstPage();
  }

  void setFilter(TransactionListFilter filter) {
    state = state.copyWith(filter: filter);
    loadFirstPage();
  }

  Future<void> loadFirstPage() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final typeFilter = state.filter.type == null ? null : transactionTypeToString(state.filter.type!);
    // A just-created transaction is already sitting in the local outbox the
    // instant "Lưu" returns — show it right away via a fast local read
    // instead of leaving the list showing stale data until the network
    // fetch below resolves (that response would include the same pending
    // transaction, but can take a long time against a cold backend).
    final pending = await _repository.getPendingEcho(workspaceId: _workspaceId, type: typeFilter);
    if (pending.isNotEmpty) {
      final pendingIds = pending.map((t) => t.id).toSet();
      state = state.copyWith(items: [...pending, ...state.items.where((t) => !pendingIds.contains(t.id))]);
    }
    try {
      final result = await _repository.getTransactions(
        workspaceId: _workspaceId,
        type: typeFilter,
        fromDate: state.filter.effectiveFromDate,
        toDate: state.filter.effectiveToDate,
        page: 1,
      );
      state = state.copyWith(
        items: result.data,
        page: result.page,
        totalPages: result.totalPages,
        isLoading: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    }
  }

  Future<void> loadNextPage() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final nextPage = state.page + 1;
      final result = await _repository.getTransactions(
        workspaceId: _workspaceId,
        type: state.filter.type == null ? null : transactionTypeToString(state.filter.type!),
        fromDate: state.filter.effectiveFromDate,
        toDate: state.filter.effectiveToDate,
        page: nextPage,
      );
      state = state.copyWith(
        items: [...state.items, ...result.data],
        page: result.page,
        totalPages: result.totalPages,
        isLoadingMore: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoadingMore: false, errorMessage: e.message);
    }
  }

  /// Optimistically marks a transaction as voided in the local list after a
  /// successful `/transactions/:id/void` call.
  void replaceTransaction(Transaction updated) {
    state = state.copyWith(
      items: [for (final t in state.items) if (t.id == updated.id) updated else t],
    );
  }
}

final transactionListProvider =
    StateNotifierProvider.autoDispose<TransactionListNotifier, TransactionListState>((ref) {
  final workspaceId = ref.watch(currentWorkspaceIdProvider);
  return TransactionListNotifier(ref.watch(transactionRepositoryProvider), workspaceId);
});
