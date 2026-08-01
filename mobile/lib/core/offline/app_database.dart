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
      version: 1,
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
            last_error TEXT
          )
        ''');
      },
    );
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
  /// in a list before the real server id exists.
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
      'last_error': null,
    });
  }

  /// Returns queued rows with `payload` already decoded back into a `Map`
  /// (it's stored as a JSON string internally) so every caller works with
  /// the same shape it originally enqueued.
  Future<List<Map<String, dynamic>>> getPendingOperations({String? workspaceId}) async {
    final db = await database;
    final rows = await db.query(
      'pending_operations',
      where: workspaceId != null ? 'workspace_id = ?' : null,
      whereArgs: workspaceId != null ? [workspaceId] : null,
      orderBy: 'created_at ASC',
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

  Future<void> setOperationError(int id, String error) async {
    final db = await database;
    await db.update('pending_operations', {'last_error': error}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> countPendingOperations({String? workspaceId}) async {
    final db = await database;
    final rows = await db.query(
      'pending_operations',
      columns: ['COUNT(*) as c'],
      where: workspaceId != null ? 'workspace_id = ?' : null,
      whereArgs: workspaceId != null ? [workspaceId] : null,
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }
}
