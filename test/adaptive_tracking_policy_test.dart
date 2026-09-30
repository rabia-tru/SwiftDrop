import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/services/adaptive_tracking_policy.dart';

void main() {
  group('AdaptiveTrackingPolicy', () {
    test('starts in active mode with full-resolution settings', () {
      final p = AdaptiveTrackingPolicy();
      expect(p.mode, TrackingMode.active);
      expect(p.distanceFilter, AdaptiveTrackingPolicy.activeDistanceFilter);
    });

    test('sustained slow speed downgrades active → walking after hold', () {
      var t = DateTime(2026, 1, 1, 9);
      final p = AdaptiveTrackingPolicy(now: () => t);

      // Moving fast initially.
      expect(p.onFix(8.0, at: t), TrackingMode.active);

      // Slow down; within the hold window the mode stays active.
      t = t.add(const Duration(seconds: 20));
      expect(p.onFix(0.5, at: t), TrackingMode.active,
          reason: 'activeHold not yet elapsed');

      // Past the hold, below walking speed but not yet idle.
      t = t.add(const Duration(seconds: 30));
      expect(p.onFix(0.5, at: t), TrackingMode.walking);
    });

    test('walking pace keeps active only during hold, then downgrades', () {
      var t = DateTime(2026, 1, 1, 9);
      final p = AdaptiveTrackingPolicy(now: () => t);

      p.onFix(9.0, at: t);
      t = t.add(const Duration(seconds: 50));
      // At walking speed the activeHold does NOT downgrade (fix says
      // "moving at ≥ walking speed" — keep resolution).
      expect(p.onFix(2.0, at: t), TrackingMode.active);
    });

    test('sustained stillness downgrades to idle after stationaryAfter', () {
      var t = DateTime(2026, 1, 1, 9);
      final p = AdaptiveTrackingPolicy(now: () => t);

      p.onFix(9.0, at: t);
      t = t.add(const Duration(seconds: 60));
      expect(p.onFix(0.0, at: t), TrackingMode.walking);

      // 90 s of stillness from the last fast fix... stationaryAfter is
      // measured from when slowness was first observed continuously.
      t = t.add(const Duration(seconds: 35));
      expect(p.onFix(0.0, at: t), TrackingMode.idle);
    });

    test('brief slowdown inside hold does not downgrade (traffic light)', () {
      var t = DateTime(2026, 1, 1, 9);
      final p = AdaptiveTrackingPolicy(now: () => t);

      p.onFix(10.0, at: t);
      t = t.add(const Duration(seconds: 10));
      expect(p.onFix(0.0, at: t), TrackingMode.active);
      t = t.add(const Duration(seconds: 10));
      expect(p.onFix(11.0, at: t), TrackingMode.active,
          reason: 'back to speed — no downgrade should have happened');
    });

    test('movement upgrades walking → active immediately (no hysteresis up)', () {
      var t = DateTime(2026, 1, 1, 9);
      final p = AdaptiveTrackingPolicy(now: () => t);

      p.onFix(9.0, at: t);
      t = t.add(const Duration(seconds: 60));
      expect(p.onFix(0.5, at: t), TrackingMode.walking);
      t = t.add(const Duration(seconds: 5));
      expect(p.onFix(6.0, at: t), TrackingMode.active,
          reason: 'upgrades must be instant to keep track quality');
    });

    test('idle wakes on fast fix, upgrading to active', () {
      var t = DateTime(2026, 1, 1, 9);
      final p = AdaptiveTrackingPolicy(now: () => t);

      p.onFix(9.0, at: t);
      t = t.add(const Duration(seconds: 200));
      expect(p.onFix(0.0, at: t), TrackingMode.idle);

      t = t.add(const Duration(minutes: 2));
      expect(p.onFix(7.0, at: t), TrackingMode.active);
    });

    test('idle wakes to walking on walking-speed fix', () {
      var t = DateTime(2026, 1, 1, 9);
      final p = AdaptiveTrackingPolicy(now: () => t);

      p.onFix(9.0, at: t);
      t = t.add(const Duration(seconds: 200));
      p.onFix(0.0, at: t);
      expect(p.mode, TrackingMode.idle);

      t = t.add(const Duration(minutes: 2));
      expect(p.onFix(1.8, at: t), TrackingMode.walking);
    });

    test('staying slow while idle keeps idle (keep-alive pings)', () {
      var t = DateTime(2026, 1, 1, 9);
      final p = AdaptiveTrackingPolicy(now: () => t);

      p.onFix(9.0, at: t);
      t = t.add(const Duration(seconds: 200));
      p.onFix(0.0, at: t);
      expect(p.mode, TrackingMode.idle);

      t = t.add(const Duration(minutes: 2));
      expect(p.onFix(0.0, at: t), TrackingMode.idle);
    });

    test('shouldFastSync only in active mode at real movement speeds', () {
      final p = AdaptiveTrackingPolicy();
      expect(p.shouldFastSync(8.0), isTrue);
      expect(p.shouldFastSync(0.0), isFalse);
      expect(p.shouldFastSync(0.0), isFalse,
          reason: 'mode unchanged (active) but speed below walking');
    });

    test('null speed is treated as stationary (gap-aware)', () {
      var t = DateTime(2026, 1, 1, 9);
      final p = AdaptiveTrackingPolicy(now: () => t);
      p.onFix(9.0, at: t);

      // Short gap: still inside the hysteresis windows.
      t = t.add(const Duration(seconds: 20));
      expect(p.onFix(null, at: t), TrackingMode.active);

      // Long silent gap (no fixes because the rider never moved): the
      // stillness counts from the previous fix → straight to idle.
      t = t.add(const Duration(seconds: 200));
      expect(p.onFix(null, at: t), TrackingMode.idle);
    });

    test('distanceFilter matches mode thresholds', () {
      final p = AdaptiveTrackingPolicy();
      expect(p.distanceFilter, 10);
      // Drive mode transitions:
      var t = DateTime(2026, 1, 1, 9);
      p.onFix(9.0, at: t);
      t = t.add(const Duration(seconds: 60));
      p.onFix(0.5, at: t); // → walking
      expect(p.distanceFilter, 50);
      t = t.add(const Duration(seconds: 200));
      p.onFix(0.0, at: t); // → idle
      expect(p.distanceFilter, 150);
    });
  });

  group('distanceMeters', () {
    test('zero distance for identical coordinates', () {
      expect(distanceMeters(31.52, 74.35, 31.52, 74.35), closeTo(0, 0.001));
    });

    test('known distance ~111 km per degree of latitude', () {
      final d = distanceMeters(30.0, 74.0, 31.0, 74.0);
      expect(d, closeTo(111000, 500));
    });
  });
}
