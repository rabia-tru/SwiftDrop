import 'package:geolocator/geolocator.dart';

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
  static Future<LocationPermissionResult> requestFullAccess() async {
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
}
