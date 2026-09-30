import 'dart:io';

import 'package:geolocator/geolocator.dart';

import 'ios_native_location_service.dart';

class LocationPermissionResult {
  final bool granted;
  final bool backgroundGranted;
  final String message;
  LocationPermissionResult(this.granted, this.backgroundGranted, this.message);
}

class LocationPermissionHelper {
  /// Android requires TWO separate permission requests to get true
  /// background access:
  /// 1. First ask for "while in use" (ACCESS_FINE_LOCATION)
  /// 2. Then separately ask for "allow all the time" (ACCESS_BACKGROUND_LOCATION)
  /// You cannot request both at once — the OS will silently ignore it.
  ///
  /// iOS: uses one CLLocationManager.requestAlwaysAuthorization() prompt,
  /// driven through the native method channel (see AppDelegate.swift).
  static Future<LocationPermissionResult> requestFullAccess() async {
    if (Platform.isIOS) return _requestIos();

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationPermissionResult(
        false,
        false,
        'Location services are turned off. Please enable GPS.',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationPermissionResult(
          false,
          false,
          'Location permission denied.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationPermissionResult(
        false,
        false,
        'Location permission permanently denied. Please enable it from app settings.',
      );
    }

    // At this point we have "while in use". Now check/request "always".
    final hasBackground = permission == LocationPermission.always;

    if (!hasBackground) {
      // On Android, calling requestPermission again after already having
      // "while in use" granted will prompt for the "Allow all the time" option.
      final upgraded = await Geolocator.requestPermission();
      return LocationPermissionResult(
        true,
        upgraded == LocationPermission.always,
        upgraded == LocationPermission.always
            ? 'Full background access granted.'
            : 'Only "while using app" granted — background sync will pause when the app is closed. Please select "Allow all the time" in settings for uninterrupted tracking.',
      );
    }

    return LocationPermissionResult(true, true, 'Full background access granted.');
  }

  /// iOS path: the native side calls CLLocationManager.requestAlwaysAuthorization()
  /// and reports the current status. "Always" is what enables
  /// allowsBackgroundLocationUpdates to keep GPS flowing while suspended.
  static Future<LocationPermissionResult> _requestIos() async {
    final status = await IosNativeLocationService.requestPermissions();
    switch (status) {
      case 'always':
        return LocationPermissionResult(true, true, 'Full background access granted.');
      case 'whenInUse':
        // The upgrade prompt was just shown — iOS will callback with the
        // result. Until "Always" is granted, tracking only works while the
        // app is on screen.
        return LocationPermissionResult(
          true,
          false,
          'Only "while using app" granted — for uninterrupted tracking, enable "Location > Always" in Settings.',
        );
      case 'notDetermined':
        return LocationPermissionResult(
          false,
          false,
          'Please allow location access (choose "Always" for background tracking).',
        );
      case 'denied':
        return LocationPermissionResult(
          false,
          false,
          'Location permission denied. Enable it in Settings > Privacy > Location Services.',
        );
      case 'restricted':
        return LocationPermissionResult(
          false,
          false,
          'Location access is restricted on this device (e.g. parental controls).',
        );
      default:
        // Native side unavailable (e.g. hot restart before channel ready)
        // — fall through to Geolocator so the UI still gets an answer.
        final p = await Geolocator.checkPermission();
        final granted = p == LocationPermission.always || p == LocationPermission.whileInUse;
        return LocationPermissionResult(
          granted,
          p == LocationPermission.always,
          granted ? 'Location access granted.' : 'Location permission not determined.',
        );
    }
  }
}
