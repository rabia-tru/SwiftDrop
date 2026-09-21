import 'dart:io';
import '../services/api_service.dart';

/// Converts technical errors into friendly, readable messages for users.
class ErrorHelper {
  /// Main entry point — pass any exception and get a clean message.
  static String getMessage(dynamic error) {
    if (error == null) return 'Something went wrong. Please try again.';

    // ── 1. Check ApiException TYPE first (not string) ──
    if (error is ApiException) {
      return _mapApiMessage(error.message);
    }

    final raw = error.toString();

    // ── 2. Network / Connection errors ──
    if (error is SocketException) {
      return 'No internet connection. Please check your WiFi or mobile data.';
    }
    if (error is HttpException) {
      return 'Unable to reach the server. Please try again later.';
    }
    if (raw.contains('TimeoutException') || raw.contains('timed out')) {
      return 'Connection timed out. Please try again.';
    }
    if (raw.contains('Connection refused') || raw.contains('errno = 111')) {
      return 'Server is not running. Please try again later.';
    }
    if (raw.contains('Connection reset') || raw.contains('Connection closed')) {
      return 'Connection was interrupted. Please try again.';
    }
    if (raw.contains('SocketException') || raw.contains('OS Error')) {
      if (raw.contains('Connection refused') || raw.contains('127.0.0.1') || raw.contains('192.168')) {
        return 'Cannot reach the server. Please make sure the app is connected.';
      }
      return 'No internet connection. Please check your network.';
    }

    // ── 3. HTTP status codes in raw string ──
    if (raw.contains('401') || raw.toLowerCase().contains('unauthorized')) {
      return 'Invalid email or password. Please try again.';
    }
    if (raw.contains('403') || raw.toLowerCase().contains('forbidden')) {
      return 'You don\'t have permission to do this.';
    }
    if (raw.contains('404') || raw.toLowerCase().contains('not found')) {
      return 'Account not found. Please check your details.';
    }
    if (raw.contains('409') || raw.toLowerCase().contains('conflict') || raw.toLowerCase().contains('already exists')) {
      return 'An account with this email already exists. Try logging in instead.';
    }
    if (raw.contains('500') || raw.toLowerCase().contains('internal server')) {
      return 'Something went wrong on our end. Please try again later.';
    }

    // ── 4. Format errors ──
    if (raw.contains('Format') || raw.contains('Invalid character')) {
      return 'Something went wrong. Please try again.';
    }

    // ── 5. URL/IP in error = connection issue ──
    if (raw.contains('127.0.0.1') || raw.contains('192.168') || raw.contains('http://')) {
      return 'Cannot reach the server. Please check your connection.';
    }

    // ── 5b. DNS / no route ──
    if (raw.contains('DNS lookup') || raw.contains('no such host') || raw.contains('getaddr')) {
      return 'Cannot find the server. Please check your connection.';
    }

    // ── 5c. Socket connect/retry errors ──
    if (raw.contains('connect') || raw.contains('retry')) {
      return 'Cannot connect to the server. Please try again.';
    }

    // ── 6. Fallback — strip technical details ──
    return _cleanFallback(raw);
  }

  /// Map common API error messages to friendly ones.
  static String _mapApiMessage(String raw) {
    final lower = raw.toLowerCase();

    // Invalid credentials
    if (lower.contains('invalid credentials') || lower.contains('incorrect password')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (lower.contains('wrong password') || lower.contains('wrong credentials')) {
      return 'Incorrect email or password. Please try again.';
    }

    // Not found
    if (lower.contains('user not found') || lower.contains('rider not found') || lower.contains('customer not found')) {
      return 'No account found with this email. Please sign up first.';
    }
    if (lower.contains('not found')) {
      return 'No account found with this email. Please sign up first.';
    }

    // Already exists
    if (lower.contains('email already') || lower.contains('already registered') || lower.contains('already exists')) {
      return 'This email is already registered. Try logging in.';
    }

    // Token/session
    if (lower.contains('token expired') || lower.contains('session expired')) {
      return 'Your session has expired. Please log in again.';
    }

    // Network inside ApiException
    if (lower.contains('network') || lower.contains('connect')) {
      return 'No internet connection. Please check your network.';
    }

    // Validation errors
    if (lower.contains('email must be') || lower.contains('email should')) {
      return 'Please enter a valid email address.';
    }
    if (lower.contains('password must be') || lower.contains('password too short') || lower.contains('password should')) {
      return 'Password must be at least 6 characters.';
    }
    if (lower.contains('phone must be') || lower.contains('phone number') || lower.contains('phone should')) {
      return 'Please enter a valid phone number.';
    }
    if (lower.contains('name must be') || lower.contains('name should not be empty')) {
      return 'Please enter your name.';
    }

    // Generic
    if (lower.contains('unauthorized') || lower.contains('401')) {
      return 'Invalid email or password. Please try again.';
    }

    // Return the actual message if it's short and readable
    if (raw.isNotEmpty && raw.length < 80 && !raw.contains('Exception') && !raw.contains('Error')) {
      return raw;
    }

    return 'Something went wrong. Please try again.';
  }

  /// Strip technical junk and return a short fallback message.
  static String _cleanFallback(String raw) {
    var clean = raw
        .replaceAll('Exception: ', '')
        .replaceAll('Error: ', '')
        .replaceAll('SocketException: ', '')
        .replaceAll('HttpException: ', '')
        .trim();

    if (clean.length > 80) {
      clean = '${clean.substring(0, 77)}...';
    }

    return clean.isNotEmpty ? clean : 'Something went wrong. Please try again.';
  }
}
