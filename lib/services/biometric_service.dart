import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Biometric authentication service — fingerprint/face ID
class BiometricService {
  static final LocalAuthentication _localAuth = LocalAuthentication();

  /// Check if device supports biometrics
  static Future<bool> isAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } on PlatformException {
      return false;
    }
  }

  /// Get available biometric types
  static Future<List<BiometricType>> getAvailableTypes() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// Check if user has enabled biometric login
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('biometric_enabled') ?? false;
  }

  /// Enable biometric login
  static Future<void> enable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', true);
  }

  /// Disable biometric login
  static Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', false);
  }

  /// Authenticate with biometrics
  static Future<bool> authenticate({String reason = 'Verify your identity to continue'}) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } on PlatformException {
      return false;
    }
  }

  /// Show setup dialog after registration — returns true if user enabled biometrics
  static Future<bool> showSetupDialog(context) async {
    final available = await isAvailable();
    if (!available) return false;

    final types = await getAvailableTypes();
    if (types.isEmpty) return false;

    String biometricName = 'biometrics';
    if (types.contains(BiometricType.face)) {
      biometricName = 'Face ID';
    } else if (types.contains(BiometricType.fingerprint)) {
      biometricName = 'Fingerprint';
    } else if (types.contains(BiometricType.iris)) {
      biometricName = 'Iris';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6D00).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.fingerprint_rounded, color: Color(0xFFFF6D00), size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Enable $biometricName',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Text(
          'Use $biometricName for faster sign-in next time? You can change this later in Settings.',
          style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF666666)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Skip', style: TextStyle(color: Color(0xFF999999))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6D00),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Enable $biometricName'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final authenticated = await authenticate(reason: 'Verify your $biometricName to enable it');
      if (authenticated) {
        await enable();
        return true;
      }
    }

    return false;
  }
}
