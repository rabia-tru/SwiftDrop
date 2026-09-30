import 'api_service.dart';
import 'location_queue_db.dart';

/// Signature of the "where does a GPS fix go" hook. The default
/// implementation writes to the local SQLite queue (never lose a ping);
/// tests replace it with an in-memory recorder.
typedef LocationPingSink = Future<void> Function(
  String orderId,
  double latitude,
  double longitude,
  double? speed,
  double? accuracy,
);

/// Upload function hook. The default calls the real backend; tests swap it
/// for a fake so no network is needed.
typedef LocationSyncFn = Future<int> Function(
  List<Map<String, dynamic>> payload,
);

/// HTTP-free, isolate-free core of the rider location pipeline:
///
///   GPS fix → LocationQueueDb (SQLite, durable) → ApiService.syncLocationBatch
///           → pings deleted from the queue ONLY after the server confirms.
///
/// `unified_background_service.dart` delegates to this so its behavior and
/// this pipeline are guaranteed to stay identical. Hooks are injectable so
/// the flow can be verified in `flutter test` without Geolocator/network.
class LocationPingPipeline {
  final LocationPingSink sink;
  final LocationSyncFn syncFn;
  final int immediateSyncThresholdSeconds;
  final int batchSize;

  DateTime? _lastImmediateSync;

  LocationPingPipeline({
    LocationPingSink? sink,
    LocationSyncFn? syncFn,
    this.immediateSyncThresholdSeconds = 5,
    this.batchSize = 100,
  })  : sink = sink ?? _defaultSink,
        syncFn = syncFn ?? _defaultSync;

  /// Default GPS-fix destination: local SQLite first, network later.
  static Future<void> _defaultSink(
    String orderId,
    double latitude,
    double longitude,
    double? speed,
    double? accuracy,
  ) {
    return LocationQueueDb.enqueue(
      latitude: latitude,
      longitude: longitude,
      speed: speed,
      accuracy: accuracy,
      orderId: orderId,
      recordedAt: DateTime.now(),
    );
  }

  /// Default upload: the same endpoint the background service uses.
  static Future<int> _defaultSync(List<Map<String, dynamic>> payload) {
    return ApiService.syncLocationBatch(payload);
  }

  /// True when a fix arriving now should trigger an immediate fast-path
  /// sync (throttled by [immediateSyncThresholdSeconds], mirroring the
  /// background service's 5s fast-path).
  bool shouldImmediateSync() {
    final now = DateTime.now();
    final last = _lastImmediateSync;
    _lastImmediateSync = now;
    if (last == null) return true;
    return now.difference(last) > Duration(seconds: immediateSyncThresholdSeconds);
  }

  /// Handle one incoming GPS fix: store it, then maybe fast-sync.
  /// Mirrors the position-stream listener in UnifiedBackgroundService.
  Future<void> handleFix({
    required String orderId,
    required double latitude,
    required double longitude,
    double? speed,
    double? accuracy,
  }) async {
    if (orderId.isEmpty) return; // tracking off — drop fix (no queue write)

    await sink(orderId, latitude, longitude, speed, accuracy);
    if (shouldImmediateSync()) {
      await syncPending();
    }
  }

  /// Drain the local queue to the server. Returns how many pings the
  /// server reported saving. Pings are removed from the queue only after
  /// the server confirms, so a failed upload keeps everything for retry.
  Future<int> syncPending() async {
    final pending = await LocationQueueDb.getPendingBatch(limit: batchSize);
    if (pending.isEmpty) return 0;

    final payload = pending
        .map((row) => {
              'latitude': row['latitude'],
              'longitude': row['longitude'],
              'speed': row['speed'],
              'accuracy': row['accuracy'],
              'orderId': row['orderId'],
              'recordedAt': row['recordedAt'],
            })
        .toList();

    try {
      final saved = await syncFn(payload);
      final ids = pending.map((row) => row['id'] as int).toList();
      await LocationQueueDb.markSynced(ids);
      return saved;
    } catch (_) {
      // Network/server error: pings stay in the queue for the next attempt.
      return 0;
    }
  }
}
