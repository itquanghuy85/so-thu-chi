import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Local SQLite database backing the offline-first layer (Mục 14): a
/// generic key/value **response cache** (last-known-good GET responses, so
/// read screens still show data with no network) and a **pending-operations
/// outbox** (queued mutations made while offline, flushed once connectivity
/// returns).
///
/// Deliberately not a full local mirror of every entity (vaults,
/// transactions, categories, ...) with two-way sync — for a double-entry
/// bookkeeping app, reimplementing balance math and conflict resolution
/// offline is a correctness risk out of proportion to the value for a
/// shop-scale MVP. Instead: reads fall back to the last cached server
/// response, and the one write that matters most offline (recording a
/// sale/expense) is queued and replayed through the exact same backend
/// endpoint once online — the server remains the single source of truth for
/// balances.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;
    final db = await _open();
    _db = db;
    return db;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'sothuchi_offline.db');
    return openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE response_cache (
            cache_key TEXT PRIMARY KEY,
            workspace_id TEXT NOT NULL,
            body TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE pending_operations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            workspace_id TEXT NOT NULL,
            kind TEXT NOT NULL,
            endpoint TEXT NOT NULL,
            payload TEXT NOT NULL,
            local_ref TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending',
            last_error TEXT
          )
        ''');
        await db.execute(_fieldHistoryTableSql);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(_fieldHistoryTableSql);
        }
        if (oldVersion < 3) {
          await db.execute("ALTER TABLE pending_operations ADD COLUMN status TEXT NOT NULL DEFAULT 'pending'");
        }
      },
    );
  }

  // --- Field-entry history (Mục — "nhập nhanh theo lịch sử") ----------
  //
  // Purely local, per-device suggestion memory for form fields (ghi chú,
  // số tiền, ...) that tend to repeat across sales — e.g. typing "b" for a
  // note field should surface "Bán rau", "Bán trứng" from past entries.
  // Deliberately per-workspace + per-field-key, not synced to the server:
  // this is muscle-memory for data *entry*, not business data itself.

  static const _fieldHistoryTableSql = '''
    CREATE TABLE field_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      workspace_id TEXT NOT NULL,
      field_key TEXT NOT NULL,
      value TEXT NOT NULL,
      use_count INTEGER NOT NULL DEFAULT 1,
      last_used_at INTEGER NOT NULL,
      UNIQUE(workspace_id, field_key, value)
    )
  ''';

  /// Records that [value] was submitted for [fieldKey] (e.g.
  /// `'transaction_note'`, `'transaction_amount'`) in [workspaceId] — a
  /// no-op for blank values. Bumps the existing row's usage count if this
  /// exact value was seen before, so frequent entries naturally rise to the
  /// top of [getFieldSuggestions].
  Future<void> recordFieldValue({
    required String workspaceId,
    required String fieldKey,
    required String value,
  }) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    final db = await database;
    await db.rawInsert(
      '''
      INSERT INTO field_history (workspace_id, field_key, value, use_count, last_used_at)
      VALUES (?, ?, ?, 1, ?)
      ON CONFLICT(workspace_id, field_key, value)
      DO UPDATE SET use_count = use_count + 1, last_used_at = excluded.last_used_at
      ''',
      [workspaceId, fieldKey, trimmed, DateTime.now().millisecondsSinceEpoch],
    );
  }

  /// Up to [limit] past values for [fieldKey] in [workspaceId], most
  /// frequent then most recent first. When [prefix] is non-empty, only
  /// values starting with it (case-insensitive) are returned — this is what
  /// powers "type the first letters, see matching past entries".
  Future<List<String>> getFieldSuggestions({
    required String workspaceId,
    required String fieldKey,
    String prefix = '',
    int limit = 8,
  }) async {
    final db = await database;
    final trimmedPrefix = prefix.trim();
    final rows = await db.query(
      'field_history',
      columns: ['value'],
      where: trimmedPrefix.isEmpty
          ? 'workspace_id = ? AND field_key = ?'
          : 'workspace_id = ? AND field_key = ? AND LOWER(value) LIKE ?',
      whereArgs: trimmedPrefix.isEmpty
          ? [workspaceId, fieldKey]
          : [workspaceId, fieldKey, '${trimmedPrefix.toLowerCase()}%'],
      orderBy: 'use_count DESC, last_used_at DESC',
      limit: limit,
    );
    return rows.map((r) => r['value'] as String).toList();
  }

  // --- Response cache -------------------------------------------------

  Future<void> putCache(String key, String workspaceId, Object jsonBody) async {
    final db = await database;
    await db.insert(
      'response_cache',
      {
        'cache_key': key,
        'workspace_id': workspaceId,
        'body': jsonEncode(jsonBody),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns the decoded cached JSON body for [key], or null if nothing was
  /// ever cached (e.g. first-ever launch while offline).
  Future<dynamic> getCache(String key) async {
    final db = await database;
    final rows = await db.query('response_cache', where: 'cache_key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['body'] as String);
  }

  // --- Pending operations outbox --------------------------------------

  /// Queues a mutation to replay later. [localRef] is a client-generated id
  /// (e.g. `pending-<timestamp>`) so the caller can show an optimistic echo
  /// in a list before the real server id exists. Always starts `status =
  /// 'pending'` — see [markOperationFailed] for what happens if the server
  /// ultimately rejects it.
  Future<int> enqueueOperation({
    required String workspaceId,
    required String kind,
    required String endpoint,
    required Map<String, dynamic> payload,
    required String localRef,
  }) async {
    final db = await database;
    return db.insert('pending_operations', {
      'workspace_id': workspaceId,
      'kind': kind,
      'endpoint': endpoint,
      'payload': jsonEncode(payload),
      'local_ref': localRef,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'status': 'pending',
      'last_error': null,
    });
  }

  /// Rows still waiting to be replayed (`status = 'pending'`), with
  /// `payload` already decoded back into a `Map`. Excludes rows the server
  /// has already rejected — see [getFailedOperations] for those.
  Future<List<Map<String, dynamic>>> getPendingOperations({String? workspaceId}) async {
    final db = await database;
    final rows = await db.query(
      'pending_operations',
      where: workspaceId != null ? "workspace_id = ? AND status = 'pending'" : "status = 'pending'",
      whereArgs: workspaceId != null ? [workspaceId] : null,
      orderBy: 'created_at ASC',
    );
    return rows.map((row) {
      final payload = jsonDecode(row['payload'] as String) as Map<String, dynamic>;
      return {...row, 'payload': payload};
    }).toList();
  }

  /// Rows the server has genuinely rejected (validation, insufficient
  /// balance, ...) — kept around with their `last_error` instead of being
  /// silently dropped, so [dismissFailedOperation] is the user's own choice
  /// to make, not something that happens invisibly the moment a background
  /// sync fails.
  Future<List<Map<String, dynamic>>> getFailedOperations({String? workspaceId}) async {
    final db = await database;
    final rows = await db.query(
      'pending_operations',
      where: workspaceId != null ? "workspace_id = ? AND status = 'failed'" : "status = 'failed'",
      whereArgs: workspaceId != null ? [workspaceId] : null,
      orderBy: 'created_at DESC',
    );
    return rows.map((row) {
      final payload = jsonDecode(row['payload'] as String) as Map<String, dynamic>;
      return {...row, 'payload': payload};
    }).toList();
  }

  Future<void> deleteOperation(int id) async {
    final db = await database;
    await db.delete('pending_operations', where: 'id = ?', whereArgs: [id]);
  }

  /// Flips a row out of `status = 'pending'` the moment its POST is actually
  /// in flight, closing a race that otherwise double-shows a transaction:
  /// without this, a list refresh that lands *after* the server has
  /// committed the row but *before* [deleteOperation] runs afterward sees
  /// both the server's own copy (already in the GET response) and the
  /// still-`'pending'` local echo of the exact same transaction. Reverted
  /// back to `'pending'` by [markOperationPending] if the request turns out
  /// to have failed for connectivity reasons, so it's retried normally.
  Future<void> markOperationSyncing(int id) async {
    final db = await database;
    await db.update('pending_operations', {'status': 'syncing'}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markOperationPending(int id) async {
    final db = await database;
    await db.update('pending_operations', {'status': 'pending'}, where: 'id = ?', whereArgs: [id]);
  }

  /// Marks a queued mutation as rejected by the server — kept in the table
  /// (not deleted) so it surfaces in [getFailedOperations] until the user
  /// explicitly dismisses it via [dismissFailedOperation].
  Future<void> markOperationFailed(int id, String error) async {
    final db = await database;
    await db.update('pending_operations', {'status': 'failed', 'last_error': error}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> dismissFailedOperation(int id) => deleteOperation(id);

  Future<int> countPendingOperations({String? workspaceId}) async {
    final db = await database;
    final rows = await db.query(
      'pending_operations',
      columns: ['COUNT(*) as c'],
      where: workspaceId != null ? "workspace_id = ? AND status = 'pending'" : "status = 'pending'",
      whereArgs: workspaceId != null ? [workspaceId] : null,
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<int> countFailedOperations({String? workspaceId}) async {
    final db = await database;
    final rows = await db.query(
      'pending_operations',
      columns: ['COUNT(*) as c'],
      where: workspaceId != null ? "workspace_id = ? AND status = 'failed'" : "status = 'failed'",
      whereArgs: workspaceId != null ? [workspaceId] : null,
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }
}
