import 'dart:math';

/// ETA Calculator — Real-time ETA based on rider location and distance
/// Uses Haversine formula for accurate distance calculation
class EtaCalculator {
  // Average speeds in km/h for different scenarios
  static const double _bikeSpeed = 25.0;    // Bike in city traffic
  static const double _carSpeed = 30.0;     // Car in city traffic
  static const double _walkSpeed = 5.0;     // Walking

  /// Calculate distance between two coordinates using Haversine formula
  /// Returns distance in kilometers
  static double calculateDistance({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    const earthRadius = 6371.0; // Earth's radius in km

    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLng / 2) * sin(dLng / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// City radius beyond which the coordinates are considered cross-city /
  /// mismatched test data (rider in one city, drop in another). Real local
  /// deliveries are inside this; showing a 6-hour ETA for a food order is
  /// nonsense, so we clamp instead.
  static const double _maxSaneDistanceKm = 15.0;

  /// Hard cap on the displayed ETA regardless of distance.
  static const int _maxEtaMinutes = 45;

  /// Calculate ETA based on distance and vehicle type
  /// Returns duration in minutes
  static int calculateEtaMinutes({
    required double distanceKm,
    String vehicleType = 'bike',
  }) {
    double speed;
    switch (vehicleType.toLowerCase()) {
      case 'car':
        speed = _carSpeed;
        break;
      case 'walk':
        speed = _walkSpeed;
        break;
      default:
        speed = _bikeSpeed;
    }

    // Add 30% buffer for traffic, stops, etc.
    final effectiveSpeed = speed * 0.7;

    // Cap absurd distances (cross-city test pins, bad GPS) so the ETA
    // stays believable — an order never takes hours.
    final saneDistance = min(distanceKm, _maxSaneDistanceKm);

    // Calculate time in minutes
    final timeMinutes = (saneDistance / effectiveSpeed) * 60;

    // Minimum 1 minute, never above the hard cap
    return min(max(1, timeMinutes.ceil()), _maxEtaMinutes);
  }

  /// Get ETA string like "5 min" or "12 min"
  static String getEtaString({
    required double riderLat,
    required double riderLng,
    required double destinationLat,
    required double destinationLng,
    String vehicleType = 'bike',
  }) {
    final distance = calculateDistance(
      lat1: riderLat,
      lng1: riderLng,
      lat2: destinationLat,
      lng2: destinationLng,
    );

    final minutes = calculateEtaMinutes(
      distanceKm: distance,
      vehicleType: vehicleType,
    );

    return '$minutes min';
  }

  /// Get detailed ETA info
  static EtaInfo getEtaInfo({
    required double riderLat,
    required double riderLng,
    required double destinationLat,
    required double destinationLng,
    String vehicleType = 'bike',
  }) {
    final distance = calculateDistance(
      lat1: riderLat,
      lng1: riderLng,
      lat2: destinationLat,
      lng2: destinationLng,
    );

    final minutes = calculateEtaMinutes(
      distanceKm: distance,
      vehicleType: vehicleType,
    );

    // Determine proximity level
    String proximity;
    if (distance < 0.1) {
      proximity = 'arriving';  // < 100m
    } else if (distance < 0.5) {
      proximity = 'very_close';  // < 500m
    } else if (distance < 2.0) {
      proximity = 'nearby';  // < 2km
    } else {
      proximity = 'far';  // > 2km
    }

    return EtaInfo(
      distanceKm: distance,
      etaMinutes: minutes,
      proximity: proximity,
      displayString: _formatDistance(distance),
    );
  }

  /// Format distance for display
  static String _formatDistance(double km) {
    if (km < 1) {
      final meters = (km * 1000).round();
      return '$meters m';
    }
    return '${km.toStringAsFixed(1)} km';
  }

  /// Convert degrees to radians
  static double _toRadians(double degree) {
    return degree * pi / 180;
  }
}

/// ETA Information model
class EtaInfo {
  final double distanceKm;
  final int etaMinutes;
  final String proximity;  // 'arriving', 'very_close', 'nearby', 'far'
  final String displayString;

  const EtaInfo({
    required this.distanceKm,
    required this.etaMinutes,
    required this.proximity,
    required this.displayString,
  });

  bool get isArriving => proximity == 'arriving';
  bool get isVeryClose => proximity == 'very_close';
  bool get isNearby => proximity == 'nearby';
  bool get isFar => proximity == 'far';
}
