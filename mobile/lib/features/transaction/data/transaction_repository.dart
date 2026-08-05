import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/offline/app_database.dart';
import '../../../core/offline/sync_queue_service.dart';
import '../../../shared/providers/dio_provider.dart';
import '../domain/transaction.dart';

class TransactionRepository {
  final Dio _dio;
  final SyncQueueService _syncQueueService;
  final Ref _ref;

  TransactionRepository(this._dio, this._syncQueueService, this._ref);

  Future<TransactionPage> getTransactions({
    required String workspaceId,
    String? type,
    String? vaultId,
    DateTime? fromDate,
    DateTime? toDate,
    int page = 1,
    int limit = 20,
  }) async {
    // Only the first page is cached/replayed offline — later pages are a
    // "load more" scroll action a user isn't realistically doing mid-outage,
    // and caching every page would multiply local storage for little value.
    final cacheKey =
        'tx:$workspaceId:${type ?? ''}:${vaultId ?? ''}:${fromDate?.toIso8601String() ?? ''}:${toDate?.toIso8601String() ?? ''}:$page:$limit';
    try {
      final response = await _dio.get(ApiEndpoints.transactions, queryParameters: {
        'workspace_id': workspaceId,
        if (type != null) 'type': type,
        if (vaultId != null) 'vault_id': vaultId,
        if (fromDate != null) 'from_date': fromDate.toIso8601String(),
        if (toDate != null) 'to_date': toDate.toIso8601String(),
        'page': page,
        'limit': limit,
      });
      if (page == 1) {
        await AppDatabase.instance.putCache(cacheKey, workspaceId, response.data);
      }
      final result = TransactionPage.fromJson(response.data as Map<String, dynamic>);
      return _withPendingEcho(result, workspaceId: workspaceId, type: type, pageNumber: page);
    } on DioException catch (e) {
      final apiError = ApiException.fromDioException(e);
      if (page == 1 && (apiError.code == 'CONNECTION_ERROR' || apiError.code == 'TIMEOUT')) {
        final cached = await AppDatabase.instance.getCache(cacheKey);
        if (cached != null) {
          final result = TransactionPage.fromJson(cached as Map<String, dynamic>);
          return _withPendingEcho(result, workspaceId: workspaceId, type: type, pageNumber: page);
        }
      }
      throw apiError;
    }
  }

  /// Prepends any queued-but-not-yet-synced transactions (Mục 14) so they're
  /// visible immediately, whether the list above them came from a fresh
  /// fetch or the offline cache. Only applied to the first page, and
  /// filtered by [type] when a type filter is active, to keep it simple.
  Future<TransactionPage> _withPendingEcho(
    TransactionPage page, {
    required String workspaceId,
    required String? type,
    required int pageNumber,
  }) async {
    if (pageNumber != 1) return page;
    final pendingTransactions = await getPendingEcho(workspaceId: workspaceId, type: type);
    if (pendingTransactions.isEmpty) return page;
    return TransactionPage(
      data: [...pendingTransactions, ...page.data],
      page: page.page,
      totalPages: page.totalPages,
    );
  }

  /// The same locally-queued (not-yet-synced) transactions [_withPendingEcho]
  /// merges into a `GET /transactions` response, exposed directly so a list
  /// screen can render a just-created transaction the instant it's queued —
  /// a local SQLite read takes a few ms — instead of only seeing it once the
  /// full network round trip above resolves, which can take tens of seconds
  /// against a cold backend even though the response would include it anyway.
  Future<List<Transaction>> getPendingEcho({required String workspaceId, String? type}) async {
    // includeSyncing=true: flush() marks rows 'syncing' before the POST fires,
    // so without this the echo would be empty while the request is in-flight.
    final ops = await AppDatabase.instance.getPendingOperations(workspaceId: workspaceId, includeSyncing: true);
    return ops
        .where((op) => op['kind'] == 'create_transaction')
        .map((op) => _pendingTransactionFromOp(op))
        .where((t) => type == null || transactionTypeToString(t.type) == type)
        .toList()
        .reversed // newest queued first
        .toList();
  }

  Transaction _pendingTransactionFromOp(Map<String, dynamic> op) {
    final payload = op['payload'];
    final body = payload is Map<String, dynamic> ? payload : <String, dynamic>{};
    final type = transactionTypeFromString(body['type'] as String? ?? 'income');
    final amount = (body['amount'] as num?) ?? 0;
    final costAmount = body['cost_amount'] as num?;
    return Transaction(
      id: op['local_ref'] as String,
      type: type,
      amount: amount,
      note: body['note'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(op['created_at'] as int),
      status: 'completed',
      costAmount: costAmount,
      profit: type == TransactionType.income && costAmount != null ? amount - costAmount : null,
      pending: true,
    );
  }

  Future<Transaction> createIncome({
    required String workspaceId,
    required String toVaultId,
    required num amount,
    String? categoryId,
    String? note,
    num? costAmount,
    String? source,
  }) {
    return _create({
      'type': 'income',
      'workspace_id': workspaceId,
      'to_vault_id': toVaultId,
      'amount': amount,
      if (categoryId != null) 'category_id': categoryId,
      if (note != null && note.isNotEmpty) 'note': note,
      if (costAmount != null) 'cost_amount': costAmount,
      if (source != null) 'source': source,
    });
  }

  Future<Transaction> createExpense({
    required String workspaceId,
    required String fromVaultId,
    required num amount,
    String? categoryId,
    String? note,
    String? source,
  }) {
    return _create({
      'type': 'expense',
      'workspace_id': workspaceId,
      'from_vault_id': fromVaultId,
      'amount': amount,
      if (categoryId != null) 'category_id': categoryId,
      if (note != null && note.isNotEmpty) 'note': note,
      if (source != null) 'source': source,
    });
  }

  Future<Transaction> createTransfer({
    required String workspaceId,
    required String fromVaultId,
    required String toVaultId,
    required num amount,
    String? note,
    String? source,
  }) {
    return _create({
      'type': 'transfer',
      'workspace_id': workspaceId,
      'from_vault_id': fromVaultId,
      'to_vault_id': toVaultId,
      'amount': amount,
      if (note != null && note.isNotEmpty) 'note': note,
      if (source != null) 'source': source,
    });
  }

  /// "Bán thiếu" — increases a customer's debt.
  Future<Transaction> createDebtIncrease({
    required String workspaceId,
    required String customerId,
    required num amount,
    String? note,
    String? source,
  }) {
    return _create({
      'type': 'debt_increase',
      'workspace_id': workspaceId,
      'customer_id': customerId,
      'amount': amount,
      if (note != null && note.isNotEmpty) 'note': note,
      if (source != null) 'source': source,
    });
  }

  /// "Trả nợ" — customer pays down debt into a vault.
  Future<Transaction> createDebtDecrease({
    required String workspaceId,
    required String customerId,
    required String toVaultId,
    required num amount,
    String? source,
  }) {
    return _create({
      'type': 'debt_decrease',
      'workspace_id': workspaceId,
      'customer_id': customerId,
      'to_vault_id': toVaultId,
      'amount': amount,
      if (source != null) 'source': source,
    });
  }

  /// Always saves locally first and syncs in the background (Mục —
  /// "lưu offline trước, sync nền sau"), regardless of whether the device
  /// is online: the write goes straight into the local outbox (Mục 14) and
  /// an optimistic **pending** echo is returned immediately, so "Lưu" never
  /// makes the user wait out a network round-trip — a slow connection used
  /// to mean a visibly stuck save button, now it doesn't. A background
  /// `SyncQueueService.flush()` (fired here, not awaited) replays the exact
  /// same POST within roughly a second on a working connection; the
  /// pending echo simply persists longer on a slow/offline one, same as
  /// before this change.
  ///
  /// A genuine server-side rejection (validation, insufficient balance,
  /// wrong workspace, ...) can no longer block "Lưu" itself — by the time
  /// it's known, the sheet has already closed. It's never silently
  /// dropped, though: `SyncQueueService.flush()` marks the row `'failed'`
  /// with the server's message instead of deleting it, and
  /// `failedSyncCountProvider` surfaces it (see `OfflineBanner`) until the
  /// user reviews and dismisses it.
  Future<Transaction> _create(Map<String, dynamic> body) async {
    final localRef = 'pending-${DateTime.now().microsecondsSinceEpoch}';
    await AppDatabase.instance.enqueueOperation(
      workspaceId: body['workspace_id'] as String,
      kind: 'create_transaction',
      endpoint: ApiEndpoints.transactions,
      payload: body,
      localRef: localRef,
    );
    // Not just fire-and-forget: the OfflineBanner's pending/failed counts
    // are read-once FutureProviders, so without this the banner is stuck
    // showing "still syncing" forever once flush() actually finishes in
    // the background — nothing else would ever tell it to re-check.
    unawaited(_syncQueueService.flush().then((_) {
      _ref.invalidate(pendingSyncCountProvider);
      _ref.invalidate(failedSyncCountProvider);
    }));
    final type = transactionTypeFromString(body['type'] as String? ?? 'income');
    final amount = (body['amount'] as num?) ?? 0;
    final costAmount = body['cost_amount'] as num?;
    return Transaction(
      id: localRef,
      type: type,
      amount: amount,
      note: body['note'] as String?,
      createdAt: DateTime.now(),
      status: 'completed',
      costAmount: costAmount,
      profit: type == TransactionType.income && costAmount != null ? amount - costAmount : null,
      pending: true,
    );
  }

  /// "Xóa vĩnh viễn": unlike [voidTransaction], actually removes the row —
  /// see `TransactionsService.remove`'s doc comment for the balance math.
  Future<void> deleteTransaction(String id) async {
    try {
      await _dio.delete(ApiEndpoints.deleteTransaction(id));
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Transaction> voidTransaction(String id, {String? reason}) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.voidTransaction(id),
        data: {if (reason != null && reason.isNotEmpty) 'reason': reason},
      );
      return Transaction.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// "Sửa giao dịch": never mutates the original — the backend voids it and
  /// creates a fresh one with these values (see `TransactionsService.edit`'s
  /// doc comment). Returns the new transaction.
  Future<Transaction> editTransaction({
    required String id,
    required String type,
    required num amount,
    String? categoryId,
    String? fromVaultId,
    String? toVaultId,
    String? customerId,
    String? note,
    num? costAmount,
    String? reason,
  }) async {
    try {
      final response = await _dio.patch(ApiEndpoints.editTransaction(id), data: {
        'type': type,
        'amount': amount,
        if (categoryId != null) 'category_id': categoryId,
        if (fromVaultId != null) 'from_vault_id': fromVaultId,
        if (toVaultId != null) 'to_vault_id': toVaultId,
        if (customerId != null) 'customer_id': customerId,
        if (note != null && note.isNotEmpty) 'note': note,
        if (costAmount != null) 'cost_amount': costAmount,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });
      final body = response.data as Map<String, dynamic>;
      return Transaction.fromJson(body['transaction'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(dioProvider), ref.watch(syncQueueServiceProvider), ref);
});
