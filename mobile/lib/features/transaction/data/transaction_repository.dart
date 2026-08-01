import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/offline/app_database.dart';
import '../../../shared/providers/dio_provider.dart';
import '../domain/transaction.dart';

class TransactionRepository {
  final Dio _dio;

  TransactionRepository(this._dio);

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
    final ops = await AppDatabase.instance.getPendingOperations(workspaceId: workspaceId);
    final pendingTransactions = ops
        .where((op) => op['kind'] == 'create_transaction')
        .map((op) => _pendingTransactionFromOp(op))
        .where((t) => type == null || transactionTypeToString(t.type) == type)
        .toList()
        .reversed // newest queued first
        .toList();
    if (pendingTransactions.isEmpty) return page;
    return TransactionPage(
      data: [...pendingTransactions, ...page.data],
      page: page.page,
      totalPages: page.totalPages,
    );
  }

  Transaction _pendingTransactionFromOp(Map<String, dynamic> op) {
    final payload = op['payload'];
    final body = payload is Map<String, dynamic> ? payload : <String, dynamic>{};
    return Transaction(
      id: op['local_ref'] as String,
      type: transactionTypeFromString(body['type'] as String? ?? 'income'),
      amount: (body['amount'] as num?) ?? 0,
      note: body['note'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(op['created_at'] as int),
      status: 'completed',
      pending: true,
    );
  }

  Future<Transaction> createIncome({
    required String workspaceId,
    required String toVaultId,
    required num amount,
    String? categoryId,
    String? note,
    String? source,
  }) {
    return _create({
      'type': 'income',
      'workspace_id': workspaceId,
      'to_vault_id': toVaultId,
      'amount': amount,
      if (categoryId != null) 'category_id': categoryId,
      if (note != null && note.isNotEmpty) 'note': note,
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

  /// Creates the transaction normally. If the device has no connectivity
  /// (or the server is unreachable), the write is queued in the local
  /// outbox (Mục 14) and an optimistic **pending** echo is returned instead
  /// of throwing — the caller's "Lưu" flow completes as normal, and the
  /// entry shows a "Chờ đồng bộ" badge until `SyncQueueService.flush()`
  /// (auto-triggered on reconnect) replays the exact same POST body.
  /// A genuine server-side rejection (validation, insufficient balance,
  /// wrong workspace, ...) still throws [ApiException] as before — only
  /// connectivity failures are queued.
  Future<Transaction> _create(Map<String, dynamic> body) async {
    try {
      final response = await _dio.post(ApiEndpoints.transactions, data: body);
      return Transaction.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final apiError = ApiException.fromDioException(e);
      if (apiError.code == 'CONNECTION_ERROR' || apiError.code == 'TIMEOUT') {
        final localRef = 'pending-${DateTime.now().microsecondsSinceEpoch}';
        await AppDatabase.instance.enqueueOperation(
          workspaceId: body['workspace_id'] as String,
          kind: 'create_transaction',
          endpoint: ApiEndpoints.transactions,
          payload: body,
          localRef: localRef,
        );
        return Transaction(
          id: localRef,
          type: transactionTypeFromString(body['type'] as String? ?? 'income'),
          amount: (body['amount'] as num?) ?? 0,
          note: body['note'] as String?,
          createdAt: DateTime.now(),
          status: 'completed',
          pending: true,
        );
      }
      throw apiError;
    }
  }

  Future<Transaction> voidTransaction(String id) async {
    try {
      final response = await _dio.post(ApiEndpoints.voidTransaction(id));
      return Transaction.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(dioProvider));
});
