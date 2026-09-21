import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

/// Every location reading the background service takes gets inserted here
/// FIRST, before any network call. This means even if the app is killed
/// mid-upload or there's no internet at all, the reading is never lost —
/// it just waits here until the next successful sync clears it out.
class LocationQueueDb {
  static Database? _db;

  static Future<Database> _getDb() async {
    if (_db != null) return _db!;

    final dbPath = path.join(await getDatabasesPath(), 'location_queue.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE location_pings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            speed REAL,
            accuracy REAL,
            orderId TEXT,
            recordedAt TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
    return _db!;
  }

  static Future<void> enqueue({
    required double latitude,
    required double longitude,
    double? speed,
    double? accuracy,
    String? orderId,
    required DateTime recordedAt,
  }) async {
    final db = await _getDb();
    await db.insert('location_pings', {
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed,
      'accuracy': accuracy,
      'orderId': orderId,
      'recordedAt': recordedAt.toUtc().toIso8601String(),
      'synced': 0,
    });
  }

  /// Returns unsynced pings, oldest first, capped at [limit] per batch
  /// so we never send one enormous payload after a long offline stretch.
  static Future<List<Map<String, dynamic>>> getPendingBatch({int limit = 100}) async {
    final db = await _getDb();
    return db.query(
      'location_pings',
      where: 'synced = 0',
      orderBy: 'recordedAt ASC',
      limit: limit,
    );
  }

  static Future<void> markSynced(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await _getDb();
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.rawDelete(
      'DELETE FROM location_pings WHERE id IN ($placeholders)',
      ids,
    );
  }

  static Future<int> pendingCount() async {
    final db = await _getDb();
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM location_pings WHERE synced = 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
