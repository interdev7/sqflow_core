import 'dart:async';

import 'package:sqflite/sqflite.dart';
import 'package:sqflow_core/sqflow_core.dart';
import 'package:sqflow_core/src/models/data_and_count.dart';

/// =======================================================
/// DATABASE SERVICE v1.0 🚀
/// =======================================================
///
/// A flexible, generic CRUD service for SQLite databases in Flutter/Dart.
/// Supports soft deletes, automatic timestamps, batch operations,
/// advanced querying, and schema management. Extend this class for your models (T extends Model).
///
/// **Key Features:**
/// - Lazy database initialization
/// - Automatic `created_at` / `updated_at` handling
/// - Soft delete via `deleted_at` timestamp
/// - Bulk operations in transactions for performance
/// - Integration with [WhereBuilder] and [SortBuilder] for complex queries
/// - Optional indexes and custom onCreate/onUpgrade hooks
class DatabaseService<T extends Model> {
  /// The database manager instance for this service.
  final DB dbManager;

  /// The table configuration (name, schema, fromJson, primary key, soft delete)
  final Table<T> table;

  /// Creates a new DatabaseService instance.
  ///
  /// **Example:**
  /// ```dart
  /// final userService = DatabaseService<User>(table: userTable, dbManager: db);
  /// ```
  DatabaseService({required this.dbManager, required this.table});

  // -------------------------------------------------------
  // DATABASE
  // -------------------------------------------------------

  /// Getter for the underlying SQLite [Database] instance.
  ///
  /// **Usage Note:** Avoid direct access; use CRUD methods instead.
  Future<Database> get database => dbManager.database;

  // -------------------------------------------------------
  // TIMESTAMPS ⏰
  // -------------------------------------------------------

  /// Adds automatic timestamps (`created_at` / `updated_at`) to data
  Map<String, dynamic> _withTimestamps(
    Map<String, dynamic> json, {
    bool isInsert = false,
  }) {
    final now = DateTime.now().toIso8601String();
    final result = Map<String, dynamic>.from(json);
    if (isInsert && !result.containsKey('created_at')) {
      result['created_at'] = now;
    }
    result['updated_at'] = now;
    return result;
  }

  // -------------------------------------------------------
  // CRUD 📝
  // -------------------------------------------------------

  /// Inserts a single item asynchronously.
  /// Automatically sets timestamps.
  /// Returns the row ID.
  ///
  /// **Example:**
  /// ```dart
  /// final id = await userService.insertAsync(User(id: '1', name: 'John'));
  /// print('Inserted ID: $id');
  /// ```
  Future<int> insertAsync(T item) async {
    final db = await database;
    return db.insert(
      table.name,
      _withTimestamps(item.toJson(), isInsert: true),
    );
  }

  /// Inserts a single item synchronously (fire-and-forget).
  /// Wraps [insertAsync] with callbacks.
  void insert(T item, {void Function(int id)? onSuccess, void Function(Object, StackTrace)? onError}) async {
    try {
      final id = await insertAsync(item);
      if (onSuccess != null) onSuccess(id);
    } catch (e, st) {
      if (onError != null) onError(e, st);
    }
  }

  /// Updates a single item asynchronously by primary key.
  /// Automatically updates `updated_at`.
  ///
  /// **Example:**
  /// ```dart
  /// final rows = await userService.updateAsync(User(id: '1', name: 'John Updated'));
  /// print('Updated rows: $rows');
  /// ```
  Future<int> updateAsync(T item) async {
    final db = await database;
    return db.update(
      table.name,
      _withTimestamps(item.toJson()),
      where: '${table.primaryKey} = ?',
      whereArgs: [item.id],
    );
  }

  /// Updates a single item synchronously.
  void update(T item, {void Function(int rows)? onSuccess, void Function(Object, StackTrace)? onError}) async {
    try {
      final rows = await updateAsync(item);
      if (onSuccess != null) onSuccess(rows);
    } catch (e, st) {
      if (onError != null) onError(e, st);
    }
  }

  /// Upserts a single item asynchronously (insert or replace on conflict).
  Future<void> upsertAsync(T item) async {
    final db = await database;
    await db.insert(
      table.name,
      _withTimestamps(item.toJson(), isInsert: true),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Upserts a single item synchronously.
  void upsert(T item, {void Function(Object id)? onSuccess, void Function(Object, StackTrace)? onError}) async {
    try {
      await upsertAsync(item);
      if (onSuccess != null) onSuccess(item.id);
    } catch (e, st) {
      if (onError != null) onError(e, st);
    }
  }

  // -------------------------------------------------------
  // DELETE / SOFT DELETE 🗑️
  // -------------------------------------------------------

  /// Deletes a single item asynchronously.
  /// If soft delete enabled, sets `deleted_at`.
  ///
  /// **Example:**
  /// ```dart
  /// await userService.deleteAsync('1'); // soft delete
  /// ```
  Future<int> deleteAsync(Object id, {bool force = false}) async {
    final db = await database;
    if (!table.paranoid || force) {
      return db.delete(table.name, where: '${table.primaryKey} = ?', whereArgs: [id]);
    }
    final now = DateTime.now().toIso8601String();
    return db.update(
      table.name,
      {'deleted_at': now, 'updated_at': now},
      where: '${table.primaryKey} = ?',
      whereArgs: [id],
    );
  }

  void delete(Object id, {bool force = false, void Function(int rows)? onSuccess, void Function(Object, StackTrace)? onError}) async {
    try {
      final rows = await deleteAsync(id, force: force);
      if (onSuccess != null) onSuccess(rows);
    } catch (e, st) {
      if (onError != null) onError(e, st);
    }
  }

  /// Restores a soft-deleted item asynchronously.
  Future<int> restoreAsync(Object id) async {
    if (!table.paranoid) throw StateError('Soft delete not enabled');
    final db = await database;
    return db.update(
      table.name,
      {'deleted_at': null, 'updated_at': DateTime.now().toIso8601String()},
      where: '${table.primaryKey} = ?',
      whereArgs: [id],
    );
  }

  void restore(Object id, {void Function(int rows)? onSuccess, void Function(Object, StackTrace)? onError}) async {
    try {
      final rows = await restoreAsync(id);
      if (onSuccess != null) onSuccess(rows);
    } catch (e, st) {
      if (onError != null) onError(e, st);
    }
  }

  // -------------------------------------------------------
  // BULK OPERATIONS 📦
  // -------------------------------------------------------

  Future<void> insertBatchAsync(List<T> items) async {
    if (items.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final item in items) {
      batch.insert(table.name, _withTimestamps(item.toJson(), isInsert: true), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  void insertBatch(List<T> items, {void Function(int count)? onSuccess, void Function(Object, StackTrace)? onError}) async {
    try {
      await insertBatchAsync(items);
      if (onSuccess != null) onSuccess(items.length);
    } catch (e, st) {
      if (onError != null) onError(e, st);
    }
  }

  Future<void> updateBatchAsync(List<T> items) async {
    if (items.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final item in items) {
      batch.update(table.name, _withTimestamps(item.toJson()), where: '${table.primaryKey} = ?', whereArgs: [item.id]);
    }
    await batch.commit(noResult: true);
  }

  void updateBatch(List<T> items, {void Function(int count)? onSuccess, void Function(Object, StackTrace)? onError}) async {
    try {
      await updateBatchAsync(items);
      if (onSuccess != null) onSuccess(items.length);
    } catch (e, st) {
      if (onError != null) onError(e, st);
    }
  }

  Future<void> upsertBatchAsync(List<T> items) async {
    if (items.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final item in items) {
      batch.insert(table.name, _withTimestamps(item.toJson(), isInsert: true), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  void upsertBatch(List<T> items, {void Function(int count)? onSuccess, void Function(Object, StackTrace)? onError}) async {
    try {
      await upsertBatchAsync(items);
      if (onSuccess != null) onSuccess(items.length);
    } catch (e, st) {
      if (onError != null) onError(e, st);
    }
  }

  Future<void> deleteBatchAsync(List<Object> ids, {bool force = false}) async {
    if (ids.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    for (final id in ids) {
      if (!table.paranoid || force) {
        batch.delete(table.name, where: '${table.primaryKey} = ?', whereArgs: [id]);
      } else {
        batch.update(table.name, {'deleted_at': now, 'updated_at': now}, where: '${table.primaryKey} = ?', whereArgs: [id]);
      }
    }
    await batch.commit(noResult: true);
  }

  void deleteBatch(List<Object> ids, {bool force = false, void Function(int count)? onSuccess, void Function(Object, StackTrace)? onError}) async {
    try {
      await deleteBatchAsync(ids, force: force);
      if (onSuccess != null) onSuccess(ids.length);
    } catch (e, st) {
      if (onError != null) onError(e, st);
    }
  }

  Future<void> restoreBatchAsync(List<Object> ids) async {
    if (!table.paranoid) throw StateError('Soft delete not enabled');
    if (ids.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    for (final id in ids) {
      batch.update(table.name, {'deleted_at': null, 'updated_at': now}, where: '${table.primaryKey} = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  void restoreBatch(List<Object> ids, {void Function(int count)? onSuccess, void Function(Object, StackTrace)? onError}) async {
    try {
      await restoreBatchAsync(ids);
      if (onSuccess != null) onSuccess(ids.length);
    } catch (e, st) {
      if (onError != null) onError(e, st);
    }
  }

  // -------------------------------------------------------
  // READ 🔍
  // -------------------------------------------------------

  Future<T?> readAsync(Object id, {List<String>? columns, bool withDeleted = false}) async {
    final db = await database;
    final where = WhereBuilder().eq(table.primaryKey, id);
    if (table.paranoid && !withDeleted) where.isNull('deleted_at');
    final result = await db.query(table.name, columns: columns, where: where.build(), whereArgs: where.args, limit: 1);
    if (result.isEmpty) return null;
    return table.fromJson(result.first);
  }

  void read(Object id, {List<String>? columns, void Function(T)? onSuccess, void Function(Object, StackTrace)? onError, bool withDeleted = false}) async {
    try {
      final item = await readAsync(id, columns: columns, withDeleted: withDeleted);
      if (item != null && onSuccess != null) onSuccess(item);
    } catch (e, st) {
      if (onError != null) onError(e, st);
    }
  }

  /// Checks existence by primary key.
  /// Corrected: properly returns true/false.
  Future<bool> existsAsync(Object id, {bool withDeleted = false}) async {
    final db = await database;
    final where = WhereBuilder().eq(table.primaryKey, id);
    if (table.paranoid && !withDeleted) where.isNull('deleted_at');
    final result = await db.query(table.name, columns: [table.primaryKey], where: where.build(), whereArgs: where.args, limit: 1);
    return result.isNotEmpty;
  }

  void exists(Object id, {void Function(bool exists)? onResult, void Function(Object, StackTrace)? onError, bool withDeleted = false}) async {
    try {
      final ex = await existsAsync(id, withDeleted: withDeleted);
      if (onResult != null) onResult(ex);
    } catch (e, st) {
      if (onError != null) onError(e, st);
    }
  }

  /// Returns all items with optional filtering, sorting, and pagination.
  /// Uses **single query** with COUNT(*) OVER() to avoid a second count query.
  ///
  /// **Example:**
  /// ```dart
  /// final result = await userService.readAll(
  ///   limit: 10,
  ///   offset: 0,
  ///   where: WhereBuilder().like('name', '%John%'),
  ///   sort: SortBuilder().asc('name')
  /// );
  /// print('Total: ${result.count}, Items: ${result.data.length}');
  /// ```
  Future<DataAndCount<T>> readAll({
    int limit = 20,
    int offset = 0,
    WhereBuilder? where,
    SortBuilder? sort,
    List<String>? columns,
    bool withDeleted = false,
    bool onlyDeleted = false,
  }) async {
    final db = await database;
    final effectiveWhere = where?.copy() ?? WhereBuilder();

    if (table.paranoid) {
      if (onlyDeleted) {
        effectiveWhere.isNotNull('deleted_at');
      } else if (!withDeleted && !effectiveWhere.hasConditionOn('deleted_at')) {
        effectiveWhere.isNull('deleted_at');
      }
    }

    // Build a single query with COUNT(*) OVER()
    final rows = await db.rawQuery('''
      SELECT ${columns?.join(', ') ?? '*'}, COUNT(*) OVER() AS total_count
      FROM ${table.name}
      ${effectiveWhere.isEmpty ? '' : 'WHERE ${effectiveWhere.build()}'}
      ${sort != null ? 'ORDER BY ${sort.build()}' : ''}
      LIMIT $limit OFFSET $offset
    ''', effectiveWhere.args);

    final data = rows.map(table.fromJson).toList();
    final count = rows.isNotEmpty ? (rows.first['total_count'] as int) : 0;

    return DataAndCount(data: data, count: count);
  }

  /// Executes operations in a transaction.
  ///
  /// **Example:**
  /// ```dart
  /// await userService.transaction((txn) async {
  ///   await txn.insert('users', {'id': '1', 'name': 'John'});
  ///   await txn.update('users', {'name': 'John Updated'}, where: 'id = ?', whereArgs: ['1']);
  /// });
  /// ```
  Future<R> transaction<R>(Future<R> Function(Transaction txn) action) async {
    final db = await database;
    return db.transaction(action);
  }
}
