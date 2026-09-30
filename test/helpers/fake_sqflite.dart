import 'package:sqflite/sqflite_dev.dart';
// ignore: implementation_imports — needed to satisfy setMockDatabaseFactory's
// SqfliteDatabaseFactory type requirement without an FFI/native dependency.
import 'package:sqflite/src/factory_impl.dart' as impl;
import 'package:sqflite_common/sqlite_api.dart' as api;

/// Minimal in-memory sqflite Database implementing ONLY what the app's
/// LocationQueueDb exercises: execute / insert / query / rawDelete /
/// rawQuery / close. Values are stored as plain Dart maps, so no native
/// SQLite (sqlite3.dll / FFI) is needed and tests run on any machine.
class FakeDatabase implements api.Database {
  final tables = <String, List<Map<String, Object?>>>{};
  final createdTables = <String>{};
  int _autoIncrement = 0;

  @override
  String get path => ':memory:';

  @override
  bool get isOpen => true;

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    // Handles the single CREATE TABLE statement the queue runs at open.
    final m = RegExp(r'CREATE TABLE\s+(?:IF NOT EXISTS\s+)?(\w+)', caseSensitive: false)
        .firstMatch(sql);
    if (m != null) {
      createdTables.add(m.group(1)!);
      tables.putIfAbsent(m.group(1)!, () => []);
      return;
    }
    throw UnimplementedError('FakeDatabase.execute: unsupported SQL: $sql');
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    api.ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final rows = tables.putIfAbsent(table, () => []);
    final row = Map<String, Object?>.from(values);
    _autoIncrement += 1;
    row['id'] = _autoIncrement; // mirrors SQLite AUTOINCREMENT column
    rows.add(row);
    return row['id'] as int;
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) {
    var rows = List<Map<String, Object?>>.from(tables.putIfAbsent(table, () => []));

    if (where != null) {
      rows = rows.where((row) => _matchWhere(row, where, whereArgs)).toList();
    }
    if (orderBy != null) {
      final parts = orderBy.split(RegExp(r'\s+'));
      final col = parts[0];
      final desc = parts.length > 1 && parts[1].toUpperCase() == 'DESC';
      rows.sort((a, b) {
        final av = a[col], bv = b[col];
        int c;
        if (av is num && bv is num) {
          c = av.compareTo(bv);
        } else {
          c = (av?.toString() ?? '').compareTo(bv?.toString() ?? '');
        }
        return desc ? -c : c;
      });
    }
    if (offset != null) rows = rows.skip(offset).toList();
    if (limit != null) rows = rows.take(limit).toList();
    if (columns != null) {
      rows = rows
          .map((r) => Map<String, Object?>.fromEntries(
              r.entries.where((e) => columns.contains(e.key))))
          .toList();
    }
    return Future.value(rows);
  }

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async {
    // Handles: DELETE FROM location_pings WHERE id IN (?, ?, ...)
    final m = RegExp(r'DELETE FROM\s+(\w+)', caseSensitive: false).firstMatch(sql);
    if (m == null) {
      throw UnimplementedError('FakeDatabase.rawDelete: unsupported SQL: $sql');
    }
    final rows = tables.putIfAbsent(m.group(1)!, () => []);
    final ids = arguments?.toSet() ?? <Object?>{};
    final before = rows.length;
    rows.removeWhere((row) => ids.contains(row['id']));
    return before - rows.length;
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(String sql, [List<Object?>? arguments]) {
    // Handles: SELECT COUNT(*) as count FROM location_pings WHERE synced = 0
    final countMatch =
        RegExp(r'SELECT COUNT\(\*\) as (\w+)', caseSensitive: false).firstMatch(sql);
    if (countMatch != null) {
      final table = RegExp(r'FROM\s+(\w+)', caseSensitive: false).firstMatch(sql)!.group(1)!;
      final rows = tables.putIfAbsent(table, () => []);
      final filtered = _applyRawWhere(rows, sql, arguments);
      return Future.value([
        {countMatch.group(1)!: filtered.length}
      ]);
    }
    throw UnimplementedError('FakeDatabase.rawQuery: unsupported SQL: $sql');
  }

  List<Map<String, Object?>> _applyRawWhere(
    List<Map<String, Object?>> rows,
    String sql,
    List<Object?>? args,
  ) {
    final whereMatch = RegExp(r'WHERE\s+(.+)$', caseSensitive: false).firstMatch(sql);
    if (whereMatch == null) return rows;
    return rows.where((row) => _matchWhere(row, whereMatch.group(1)!, args)).toList();
  }

  bool _matchWhere(Map<String, Object?> row, String where, List<Object?>? args) {
    final chunks = where.split(RegExp(r'\bAND\b', caseSensitive: false));
    var argIndex = 0;
    for (final chunk in chunks) {
      // Matches "col = ?" (parameterized) and "col = <literal>" (e.g.
      // "synced = 0", as LocationQueueDb filters unsynced rows).
      final m = RegExp(r"^\s*(\w+)\s*=\s*(?:\?|('[^']*'|[\w.@:T+.\-]+))\s*$")
          .firstMatch(chunk);
      if (m == null) return false; // unsupported WHERE clause shape
      final col = m.group(1)!;
      final placeholder = m.group(2);
      final Object? expected;
      if (placeholder == '?') {
        expected = args?[argIndex++];
      } else if (placeholder!.startsWith("'")) {
        expected = placeholder.substring(1, placeholder.length - 1);
      } else {
        expected = num.tryParse(placeholder) ?? placeholder;
      }
      if (row[col] != expected) return false;
    }
    return true;
  }

  // ── Members below exist on the Database interface but are not used by
  // LocationQueueDb; they throw if ever reached so tests fail loudly.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation); // explicit: default behavior

  @override
  api.Batch batch() => throw UnimplementedError();

  @override
  Future<void> close() async {}

  @override
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) =>
      throw UnimplementedError();

  @override
  Future<T> devInvokeMethod<T>(String method, [Object? arguments]) =>
      throw UnimplementedError();

  @override
  Future<T> devInvokeSqlMethod<T>(String method, String sql, [List<Object?>? arguments]) =>
      throw UnimplementedError();

  @override
  Future<T> readTransaction<T>(Future<T> Function(api.Transaction txn) action) =>
      throw UnimplementedError();

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) => throw UnimplementedError();

  @override
  Future<api.QueryCursor> queryCursor(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
    int? bufferSize,
  }) =>
      throw UnimplementedError();

  @override
  Future<api.QueryCursor> rawQueryCursor(String sql, List<Object?>? arguments,
          {int? bufferSize}) =>
      throw UnimplementedError();

  @override
  Future<T> transaction<T>(Future<T> Function(api.Transaction txn) action,
          {bool? exclusive}) =>
      throw UnimplementedError();

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    api.ConflictAlgorithm? conflictAlgorithm,
  }) =>
      throw UnimplementedError();

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) =>
      throw UnimplementedError();
}

/// DatabaseFactory handing out one shared FakeDatabase per unique path —
/// mirrors sqflite's singleInstance behavior so repeated
/// LocationQueueDb calls within a test hit the same rows.
///
/// Extends sqflite's real factory impl purely to satisfy the
/// SqfliteDatabaseFactory type cast inside setMockDatabaseFactory; the two
/// methods LocationQueueDb actually exercises are overridden.
class FakeDatabaseFactory extends impl.SqfliteDatabaseFactoryImpl {
  final instances = <String, FakeDatabase>{};

  /// Directory returned by getDatabasesPath(). LocationQueueDb joins this
  /// with its hardcoded 'location_queue.db' filename, so bumping this per
  /// test gives every test a pristine database despite the static handle
  /// cache inside LocationQueueDb.
  String databasesPath = '/fake_databases_0';
  var _pathCounter = 0;

  void resetDatabasesPath() {
    _pathCounter += 1;
    databasesPath = '/fake_databases_$_pathCounter';
  }

  @override
  Future<String> getDatabasesPath() async => databasesPath;

  @override
  Future<api.Database> openDatabase(String path, {api.OpenDatabaseOptions? options}) async {
    final db = instances.putIfAbsent(path, FakeDatabase.new);
    await options?.onCreate?.call(db, options.version ?? 1);
    return db;
  }
}

/// Installs the fake as sqflite's global factory. Call in setUpAll/setUp;
/// safe to call repeatedly (the last call wins).
void installFakeSqflite(FakeDatabaseFactory factory) {
  // ignore: invalid_use_of_visible_for_testing_member
  setMockDatabaseFactory(factory);
}
