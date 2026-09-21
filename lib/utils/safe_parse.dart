/// Safe parsing utilities for values that may come as String, int, or double
/// from the PostgreSQL database API.
class SafeParse {
  /// Safely converts any value to double.
  /// Handles: int, double, String("350.00"), null
  static double toDouble(dynamic value, [double fallback = 0]) {
    if (value == null) return fallback;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  /// Safely converts any value to int.
  static int toInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  /// Safely converts any value to String.
  static String toStr(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    return value.toString();
  }
}
