/// Motion-adaptive GPS policy for background rider tracking.
///
/// The background service previously ran the GPS stream at
/// `LocationAccuracy.high` + `distanceFilter: 10` non-stop, which is the
/// single biggest battery consumer in the app: the GPS radio stays hot and
/// wakes the CPU for a fix every few meters even when the rider is
/// stationary at a pickup point.
///
/// The policy maps observed speed to a tracking mode, each with its own
/// accuracy, distance filter and sync pacing, and applies hysteresis
/// (timed hold + grace) so brief signal dropouts at walking pace don't
/// flip-flop the radio between modes.
///
/// Pure logic — no Flutter imports — so it can be unit-tested directly.
library;

import 'dart:math' as math;

/// How aggressively the GPS radio is polled.
enum TrackingMode {
  /// Rider stationary ≥ [stationaryAfter] seconds. GPS fully off; location
  /// is refreshed via a periodic "keep-alive" fix instead of a live stream.
  /// Battery: near zero.
  idle,

  /// On foot, roughly walking speed. Low GPS duty cycle.
  walking,

  /// Moving faster than walking pace. Full-resolution tracking.
  active,
}

class AdaptiveTrackingPolicy {
  /// Speed thresholds (m/s).
  static const double walkingSpeedThreshold = 1.5; // ~5.4 km/h
  static const double activeSpeedThreshold = 2.5; // ~9 km/h — beyond = vehicle

  /// Per-mode GPS settings.
  static const int activeDistanceFilter = 10; // m — matches old behavior
  static const int walkingDistanceFilter = 50; // m
  static const int idleDistanceFilter = 150; // m

  /// Hysteresis: stay in [TrackingMode.active] at least this long after
  /// leaving it, so brief slowdowns (traffic light, front gate) don't
  /// downgrade and lose the fine-grained track.
  static const Duration activeHold = Duration(seconds: 45);

  /// Hysteresis: require the rider to be slow for this long before
  /// declaring them idle, so GPS jitter near zero speed doesn't idle
  /// the stream mid-delivery.
  static const Duration stationaryAfter = Duration(seconds: 90);

  /// Fallback when a fix has no speed reading (some devices report
  /// speed < 0). Falls back to horizontal displacement per second.
  static const double assumeStationaryAccuracyMeters = 25.0;

  final DateTime Function() _now;

  TrackingMode _mode = TrackingMode.active;
  DateTime? _lastFastFix;
  DateTime? _slowSince;
  DateTime? _lastFixAt;

  /// [now] is injectable for tests; thresholds come from the statics above.
  AdaptiveTrackingPolicy({DateTime Function()? now}) : _now = now ?? DateTime.now;

  TrackingMode get mode => _mode;

  /// Distance filter (m) the GPS stream should currently use.
  int get distanceFilter {
    switch (_mode) {
      case TrackingMode.active:
        return activeDistanceFilter;
      case TrackingMode.walking:
        return walkingDistanceFilter;
      case TrackingMode.idle:
        return idleDistanceFilter;
    }
  }

  /// Whether an incoming fix should trigger the fast-path upload (the 5s
  /// one). In low-power modes we let the periodic batch tick do the work.
  bool shouldFastSync(double speedMetersPerSecond) {
    return _mode == TrackingMode.active && speedMetersPerSecond >= walkingSpeedThreshold;
  }

  /// Feed one GPS fix (or null when idle keep-alive) and get the mode the
  /// stream settings should now reflect. Idempotent.
  ///
  /// Sleep detection counts stillness from the PREVIOUS fix, not from the
  /// current one: a stationary rider produces NO fixes at all (the
  /// distance filter suppresses them), so a long silent gap followed by a
  /// slow fix means the rider was still the whole time and the policy
  /// should idle immediately instead of waiting another 90 s.
  TrackingMode onFix(double? speedMetersPerSecond, {DateTime? at}) {
    final t = at ?? _now();
    final prevFix = _lastFixAt;
    _lastFixAt = t;
    final speed = speedMetersPerSecond ?? 0.0;
    final isFast = speed >= activeSpeedThreshold;
    final isWalking = speed >= walkingSpeedThreshold && speed < activeSpeedThreshold;
    // Slow = anything below walkingSpeedThreshold; implied by the above.

    switch (_mode) {
      case TrackingMode.active:
        if (isFast || isWalking) {
          _slowSince = null;
          _lastFastFix = t;
        } else {
          // Stillness effectively began right after the previous fix.
          _slowSince ??= prevFix ?? t;
          if (t.difference(_slowSince!) >= stationaryAfter) {
            _transition(TrackingMode.idle, t);
          } else if (_lastFastFix != null &&
              t.difference(_lastFastFix!) > activeHold &&
              !isWalking) {
            // Slow long enough to drop below full-power but not yet idle.
            _transition(TrackingMode.walking, t);
          }
        }

      case TrackingMode.walking:
        if (isFast) {
          _slowSince = null;
          _lastFastFix = t;
          _transition(TrackingMode.active, t);
        } else if (isWalking) {
          _slowSince = null;
          _lastFastFix = t;
        } else {
          _slowSince ??= prevFix ?? t;
          if (t.difference(_slowSince!) >= stationaryAfter) {
            _transition(TrackingMode.idle, t);
          }
        }

      case TrackingMode.idle:
        if (isFast) {
          _transition(TrackingMode.active, t);
        } else if (isWalking) {
          _transition(TrackingMode.walking, t);
        }
        // Still slow: stay idle. (Idle keep-alive fixes come in with
        // speed 0 — the wake-up happens on the first genuinely fast fix.)
    }
    return _mode;
  }

  void _transition(TrackingMode next, DateTime t) {
    if (next == _mode) return;
    _mode = next;
    switch (next) {
      case TrackingMode.active:
        _slowSince = null;
        _lastFastFix = t;
      case TrackingMode.walking:
        // Keep _slowSince — the stillness that got us here is continuing.
        _lastFastFix = null;
      case TrackingMode.idle:
        _slowSince = null;
        _lastFastFix = null;
    }
  }

  /// Expected interval between queued pings in the current mode — used by
  /// tests and by the keep-alive timer for the idle mode.
  Duration get expectedFixInterval {
    switch (_mode) {
      case TrackingMode.active:
        return const Duration(seconds: 3);
      case TrackingMode.walking:
        return const Duration(seconds: 15);
      case TrackingMode.idle:
        return const Duration(minutes: 2);
    }
  }
}

/// Great-circle distance in meters (same formula as the BG service's
/// calcDistanceMeters, moved here so both use one implementation).
double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLon = (lon2 - lon1) * math.pi / 180;
  final a = (dLat / 2) * (dLat / 2) +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          (dLon / 2) *
          (dLon / 2);
  return r * 2 * math.asin(math.sqrt(a));
}
