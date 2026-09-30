import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/services/service_watchdog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // MethodChannel calls need the services binding initialized, even when
  // they end in MissingPluginException (no mock handler registered).
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ServiceWatchdog.decide (contract mirrored by WatchdogReceiver.kt)', () {
    const now = 1_000_000_000_000;

    test('disarmed → always ignore, never restart', () {
      expect(
        ServiceWatchdog.decide(
          armed: false,
          anyJobActive: true,
          heartbeatMs: 0,
          nowMs: now,
        ),
        WatchdogDecision.ignore,
      );
    });

    test('armed but no active jobs → self-disarm (chain ends)', () {
      expect(
        ServiceWatchdog.decide(
          armed: true,
          anyJobActive: false,
          heartbeatMs: now - 1000,
          nowMs: now,
        ),
        WatchdogDecision.selfDisarm,
      );
    });

    test('fresh heartbeat → healthy, rearm only', () {
      expect(
        ServiceWatchdog.decide(
          armed: true,
          anyJobActive: true,
          heartbeatMs: now - 30_000, // one beat interval old
          nowMs: now,
        ),
        WatchdogDecision.rearmOnly,
      );
      // Just inside the staleness window.
      expect(
        ServiceWatchdog.decide(
          armed: true,
          anyJobActive: true,
          heartbeatMs: now - 89_999,
          nowMs: now,
        ),
        WatchdogDecision.rearmOnly,
      );
    });

    test('stale heartbeat → restart the service', () {
      expect(
        ServiceWatchdog.decide(
          armed: true,
          anyJobActive: true,
          heartbeatMs: now - 91_000,
          nowMs: now,
        ),
        WatchdogDecision.restartService,
      );
      // Hours old (device slept, OEM froze everything).
      expect(
        ServiceWatchdog.decide(
          armed: true,
          anyJobActive: true,
          heartbeatMs: now - 3_600_000,
          nowMs: now,
        ),
        WatchdogDecision.restartService,
      );
    });

    test('missing heartbeat (never beaten) → restart', () {
      expect(
        ServiceWatchdog.decide(
          armed: true,
          anyJobActive: true,
          heartbeatMs: 0,
          nowMs: now,
        ),
        WatchdogDecision.restartService,
      );
    });

    test('custom staleness window is honored', () {
      expect(
        ServiceWatchdog.decide(
          armed: true,
          anyJobActive: true,
          heartbeatMs: now - 45_000,
          nowMs: now,
          staleMs: 30_000,
        ),
        WatchdogDecision.restartService,
      );
    });
  });

  group('ServiceWatchdog arming flow', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ServiceWatchdog.channelOverride = null;
      // Desktop test host: force the Android code paths on.
      ServiceWatchdog.platformOverride = true;
    });
    tearDown(() {
      ServiceWatchdog.platformOverride = null;
    });

    test('beat() writes the current timestamp under the watchdog key', () async {
      await ServiceWatchdog.beat();
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(ServiceWatchdog.kHeartbeatKey)!;
      expect(ms, closeTo(DateTime.now().millisecondsSinceEpoch, 5000));
    });

    test('ensureArmed persists armed state even if the channel is unreachable', () async {
      // No platform binding in unit tests → invokeMethod throws
      // MissingPluginException → _invoke returns false. The 'already
      // armed' short-circuit is what keeps protection sticky across
      // channel hiccups, so simulate that by pre-setting the flag.
      SharedPreferences.setMockInitialValues({
        'flutter.${ServiceWatchdog.kArmedKey}': true,
      });
      await ServiceWatchdog.ensureArmed();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(ServiceWatchdog.kArmedKey), isTrue);
    });

    test('ensureArmed still writes armed=true when the channel works', () async {
      ServiceWatchdog.channelOverride = (method) async => method == 'arm';
      await ServiceWatchdog.ensureArmed();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(ServiceWatchdog.kArmedKey), isTrue);
    });

    test('disarm clears both flags', () async {
      SharedPreferences.setMockInitialValues({
        'flutter.${ServiceWatchdog.kArmedKey}': true,
        'flutter.${ServiceWatchdog.kHeartbeatKey}': 123,
      });
      ServiceWatchdog.channelOverride = (method) async => true;
      await ServiceWatchdog.disarm();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(ServiceWatchdog.kArmedKey), isFalse);
      expect(prefs.getInt(ServiceWatchdog.kHeartbeatKey), isNull);
    });
  });
}
