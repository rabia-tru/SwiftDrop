import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/services/service_watchdog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('WatchdogStatus.health verdicts', () {
    WatchdogStatus s({
      bool platformSupported = true,
      bool armed = true,
      bool canScheduleExactAlarms = true,
      int? lastBeatAge,
    }) =>
        WatchdogStatus(
          platformSupported: platformSupported,
          armed: armed,
          canScheduleExactAlarms: canScheduleExactAlarms,
          lastBeatAge: lastBeatAge,
          lastBeatAt: lastBeatAge == null
              ? null
              : DateTime.now().subtract(Duration(milliseconds: lastBeatAge)),
        );

    test('healthy: armed + alarms ok + fresh beat', () {
      expect(s(lastBeatAge: 30_000).health, WatchdogHealth.healthy);
      // Just inside the 90s window.
      expect(s(lastBeatAge: 89_000).health, WatchdogHealth.healthy);
    });

    test('stale: armed but heartbeat old — service likely killed', () {
      expect(s(lastBeatAge: 91_000).health, WatchdogHealth.stale);
      expect(s(lastBeatAge: 3_600_000).health, WatchdogHealth.stale);
    });

    test('neverRan: armed but no heartbeat ever written', () {
      expect(s(lastBeatAge: null).health, WatchdogHealth.neverRan);
    });

    test('disarmed: flag cleared after all jobs ended', () {
      expect(
        s(armed: false, lastBeatAge: null).health,
        WatchdogHealth.disarmed,
      );
    });

    test('broken: exact-alarm permission revoked overrides everything', () {
      expect(
        s(canScheduleExactAlarms: false, lastBeatAge: 30_000).health,
        WatchdogHealth.broken,
      );
      expect(
        s(canScheduleExactAlarms: false, armed: false).health,
        WatchdogHealth.broken,
        reason: 'a watchdog without alarm permission is useless even if '
            'currently disarmed — surface the problem',
      );
    });

    test('notApplicable on non-Android platforms', () {
      expect(
        s(platformSupported: false, lastBeatAge: 30_000).health,
        WatchdogHealth.notApplicable,
      );
    });

    test('maxHealthyBeatAgeMs matches the native 90s staleness window', () {
      expect(WatchdogStatus.maxHealthyBeatAgeMs, 90000);
    });
  });

  group('ServiceWatchdog.status()', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ServiceWatchdog.platformOverride = true;
      ServiceWatchdog.channelOverride = null;
    });
    tearDown(() {
      ServiceWatchdog.platformOverride = null;
      ServiceWatchdog.channelOverride = null;
    });

    test('reads persisted heartbeat age and armed flag', () async {
      final beatAt = DateTime.now().millisecondsSinceEpoch - 45_000;
      SharedPreferences.setMockInitialValues({
        'flutter.${ServiceWatchdog.kHeartbeatKey}': beatAt,
        'flutter.${ServiceWatchdog.kArmedKey}': true,
      });
      ServiceWatchdog.channelOverride = (method) async =>
          method == 'canScheduleExact'; // true only for that method

      final status = await ServiceWatchdog.status();
      expect(status.platformSupported, isTrue);
      expect(status.armed, isTrue);
      expect(status.canScheduleExactAlarms, isTrue);
      expect(status.lastBeatAge, closeTo(45_000, 5_000));
      expect(status.lastBeatAt, isNotNull);
      expect(status.health, WatchdogHealth.healthy);
    });

    test('revoked exact-alarm permission surfaces as broken', () async {
      SharedPreferences.setMockInitialValues({
        'flutter.${ServiceWatchdog.kArmedKey}': true,
      });
      ServiceWatchdog.channelOverride = (method) async => false;

      final status = await ServiceWatchdog.status();
      expect(status.canScheduleExactAlarms, isFalse);
      expect(status.health, WatchdogHealth.broken);
    });

    test('non-Android platform: not applicable, no channel calls', () async {
      ServiceWatchdog.platformOverride = false;
      var channelCalled = false;
      ServiceWatchdog.channelOverride = (method) async {
        channelCalled = true;
        return true;
      };

      final status = await ServiceWatchdog.status();
      expect(status.platformSupported, isFalse);
      expect(status.health, WatchdogHealth.notApplicable);
      expect(channelCalled, isFalse);
      expect(status.lastBeatAge, isNull);
    });

    test('fresh install (no data): neverRan, not broken', () async {
      ServiceWatchdog.channelOverride = (method) async => true;
      final status = await ServiceWatchdog.status();
      expect(status.armed, isFalse);
      expect(status.lastBeatAge, isNull);
      expect(status.health, WatchdogHealth.disarmed);
    });
  });
}
