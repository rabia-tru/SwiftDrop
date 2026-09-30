import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/config/app_config.dart';
import 'package:rider_app/services/api_service.dart';
import 'package:rider_app/services/location_ping_pipeline.dart';
import 'package:rider_app/services/location_queue_db.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Direct import: needed for InMemorySharedPreferencesStore even though it's
// not a direct pubspec dependency (it ships with the shared_preferences app facet).
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'helpers/fake_sqflite.dart';

/// End-to-end verification of the rider location pipeline:
///
///   GPS fix (simulated via a fake Geolocator fix) → LocationQueueDb
///   → ApiService.syncLocationBatch → real local HttpServer standing in
///   for the NestJS backend, validating the exact /location/sync contract:
///     POST `{base}/location/sync`
///     Authorization: Bearer token from SharedPreferences('auth_token')
///     `{ "pings": [ { latitude, longitude, speed, accuracy, orderId, recordedAt } ] }`
///     → 200 `{ "saved": n }`
///
/// The SQLite layer runs against sqflite's in-memory mock database
/// (installed via setMockDatabaseFactory), so no native SQLite is needed.
void main() {
  final dbFactory = FakeDatabaseFactory();
  late _FakeSyncServer server;
  late LocationPingPipeline pipeline;

  setUpAll(() {
    installFakeSqflite(dbFactory);
  });

  setUp(() async {
    // LocationQueueDb caches its Database handle statically AND joins a
    // hardcoded filename onto getDatabasesPath(), so bumping the fake
    // factory's databases path per test gives each test a pristine queue
    // despite the cache.
    dbFactory.resetDatabasesPath();

    // SharedPreferences backend: in-memory store; ApiService reads the
    // rider JWT from prefs key 'auth_token'.
    SharedPreferencesStorePlatform.instance = InMemorySharedPreferencesStore.empty();
    SharedPreferences.setMockInitialValues({});

    // Point the app's HTTP layer at the in-process server.
    server = await _FakeSyncServer.start();
    AppConfig.apiBaseUrl = server.baseUrl;

    // Same pipeline wiring as UnifiedBackgroundService (sink → queue,
    // syncFn → real ApiService), with the 5s fast-path throttle intact.
    pipeline = LocationPingPipeline();
    await pipeline.syncPending(); // baseline: fresh queue starts empty
  });

  tearDown(() async {
    await server.close();
  });

  test('happy path: GPS fix → queue → POST /location/sync → queue drained', () async {
    expect(await LocationQueueDb.pendingCount(), 0);

    // 1. Simulate a GPS fix arriving from Geolocator.getPositionStream.
    await pipeline.handleFix(
      orderId: 'order-1',
      latitude: 31.5204,
      longitude: 74.3587,
      speed: 8.5,
      accuracy: 5.0,
    );

    // 2. The fix was enqueued first (offline-safe), then fast-path synced.
    expect(await LocationQueueDb.pendingCount(), 0,
        reason: 'ping should be removed from the queue after server confirm');

    // 3. The server saw the exact contract the real backend validates.
    final req = server.requests.single;
    expect(req.method, 'POST');
    expect(req.path, '/api/location/sync');
    expect(req.headers['authorization'], isNull,
        reason: 'no token stored yet — header must be omitted, not malformed');

    final body = jsonDecode(req.body) as Map<String, dynamic>;
    final pings = body['pings'] as List;
    expect(pings, hasLength(1));
    final ping = pings.first as Map<String, dynamic>;
    expect(ping['latitude'], 31.5204);
    expect(ping['longitude'], 74.3587);
    expect(ping['speed'], 8.5);
    expect(ping['accuracy'], 5.0);
    expect(ping['orderId'], 'order-1');
    expect(DateTime.parse(ping['recordedAt'] as String),
        isA<DateTime>()); // ISO8601, validated by backend @IsDateString

    // 4. ApiService parsed the {saved: n} reply.
    expect(server.savedReplies, [1]);
  });

  test('authorization header carries the rider JWT from SharedPreferences', () async {
    const token = 'rider-jwt-abc123';
    SharedPreferences.setMockInitialValues({'flutter.auth_token': token});
    // Re-fetch: getToken() reads prefs key 'auth_token' (prefix 'flutter.' added by the plugin).

    await pipeline.handleFix(
      orderId: 'order-2',
      latitude: 10.0,
      longitude: 20.0,
    );

    final req = server.requests.single;
    expect(req.headers.value('authorization'), 'Bearer $token');
  });

  test('fix with empty orderId is dropped and never queued (tracking off)', () async {
    await pipeline.handleFix(
      orderId: '',
      latitude: 1.0,
      longitude: 2.0,
    );

    expect(server.requests, isEmpty);
    expect(await LocationQueueDb.pendingCount(), 0);
  });

  test('server down: ping stays queued, next sync retries and drains it', () async {
    // Fail the first request with a 503 (backend outage), then recover.
    server.failNextWith = 503;

    await pipeline.handleFix(
      orderId: 'order-3',
      latitude: 33.6844,
      longitude: 73.0479,
      speed: 0.0,
      accuracy: 8.0,
    );

    // Upload failed → ping must still be in the local queue (no data loss).
    expect(await LocationQueueDb.pendingCount(), 1);
    expect(server.savedReplies, isEmpty);

    // Backend comes back up.
    server.failNextWith = null;

    final saved = await pipeline.syncPending();
    expect(saved, 1);
    expect(await LocationQueueDb.pendingCount(), 0);
    expect(server.requests, hasLength(2));
    expect(server.requests.last.body, contains('"orderId":"order-3"'));
  });

  test('connection refused: syncPending returns 0 and keeps the queue intact', () async {
    // Point at a port with no listener to exercise the real exception path.
    AppConfig.apiBaseUrl = 'http://127.0.0.1:1/api';
    try {
      await pipeline.handleFix(
        orderId: 'order-4',
        latitude: 1.0,
        longitude: 1.0,
      );
    } on ApiException {
      // handleFix → shouldImmediateSync → syncPending swallows... actually
      // syncPending catches, so we should never land here. Keep the assert below.
    }
    expect(await LocationQueueDb.pendingCount(), 1,
        reason: 'refused connection must NOT delete the queued ping');
    expect(server.requests, isEmpty);
  });

  test('shouldImmediateSync throttles fast-path syncs to the 5s window', () {
    final p = LocationPingPipeline(immediateSyncThresholdSeconds: 5);
    expect(p.shouldImmediateSync(), isTrue, reason: 'first fix always syncs');
    expect(p.shouldImmediateSync(), isFalse, reason: 'inside the 5s window');
    expect(p.shouldImmediateSync(), isFalse, reason: 'still inside the 5s window');
  });

  test('batching: getPendingBatch caps uploads at 100 pings per sync', () async {
    // Seed 150 pings directly into the queue, bypassing the sink.
    for (var i = 0; i < 150; i++) {
      await LocationQueueDb.enqueue(
        latitude: 1.0 + i,
        longitude: 2.0,
        orderId: 'batch-order',
        recordedAt: DateTime.now(),
      );
    }

    final saved = await pipeline.syncPending();
    expect(saved, 100);
    expect(await LocationQueueDb.pendingCount(), 50, reason: 'remainder waits for next batch');

    final second = await pipeline.syncPending();
    expect(second, 50);
    expect(await LocationQueueDb.pendingCount(), 0);
    expect(server.requests, hasLength(2));
  });

  test('handleFix wires sink→queue and sync→server exactly like the BG service', () async {
    // End-to-end shape check with multiple fixes and throttled fast-path:
    // 3 fixes arrive within the 5s window → 1st syncs immediately, the
    // rest wait for the periodic batch tick (simulated by syncPending).
    await pipeline.handleFix(orderId: 'o', latitude: 1, longitude: 1);
    await pipeline.handleFix(orderId: 'o', latitude: 2, longitude: 2);
    await pipeline.handleFix(orderId: 'o', latitude: 3, longitude: 3);

    // First fix triggered the fast-path; the queue holds fixes 2 & 3.
    expect(await LocationQueueDb.pendingCount(), 2);

    // Periodic 30s tick (as the background service would call it).
    await pipeline.syncPending();

    expect(await LocationQueueDb.pendingCount(), 0);
    final allPings = server.requests
        .expand((r) => (jsonDecode(r.body)['pings'] as List).cast<Map<String, dynamic>>());
    expect(allPings.map((p) => p['latitude'] as num), [1, 2, 3]);
  });
}

/// Stand-in for the NestJS backend: a real localhost HTTP server that
/// records every request and replies with the backend's contract shape
/// ({saved: n}). Using a real socket (instead of mocking http.Client)
/// exercises the app's actual HTTP + JSON code path end-to-end.
class _FakeSyncServer {
  final requests = <_RecordedRequest>[];
  final savedReplies = <int>[];
  int? failNextWith;
  late HttpServer _server;

  String get baseUrl => 'http://127.0.0.1:${_server.port}/api';

  static Future<_FakeSyncServer> start() async {
    final s = _FakeSyncServer();
    s._server = await HttpServer.bind('127.0.0.1', 0);
    s._server.listen(s._handle);
    return s;
  }

  Future<void> close() async {
    await _server.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();

    requests.add(_RecordedRequest(
      method: request.method,
      path: request.uri.path,
      headers: request.headers,
      body: body,
    ));

    if (failNextWith != null) {
      final code = failNextWith!;
      failNextWith = null;
      request.response.statusCode = code;
      await request.response.close();
      return;
    }

    final decoded = body.isNotEmpty ? jsonDecode(body) as Map<String, dynamic> : {};
    final pings = (decoded['pings'] as List?) ?? [];
    savedReplies.add(pings.length);
    request.response.statusCode = 200;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'saved': pings.length}));
    await request.response.close();
  }
}

class _RecordedRequest {
  final String method;
  final String path;
  final String body;
  final HttpHeaders headers;
  _RecordedRequest({
    required this.method,
    required this.path,
    required this.body,
    required this.headers,
  });
}
