import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// SwiftDrop Design System - Orange & White Only
class AppColors {
  /// Set status bar to match light background (dark icons)
  static void setLightStatusBar() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
  }

  /// Set status bar to match orange/dark header (white icons)
  static void setDarkStatusBar() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.orange,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  // ─── Orange Primary ─────────────────────────────────────────
  static const orange = Color(0xFFFF5722);
  static const orangeDark = Color(0xFFE64A19);
  static const deepOrange = Color(0xFFD84315);
  static const orangeLight = Color(0xFFFF7043);
  // Warm tint of the BRAND orange (12% mix with white). Previously a
  // pinkish peach (#FFCCBC) that read as a different hue entirely.
  static const orangePale = Color(0xFFFFD9C2);

  // ─── White & Grays (for contrast only) ─────────────────────
  static const white = Colors.white;
  static const offWhite = Color(0xFFF9F9F9);
  static const lightGray = Color(0xFFF3F3F3);
  static const gray = Color(0xFFE0E0E0);
  static const darkGray = Color(0xFF9E9E9E);
  static const charcoal = Color(0xFF333333);
  static const black = Color(0xFF1A1A1A);

  // ─── Semantic aliases ───────────────────────────────────────
  static const primary = orange;
  static const primaryDark = orangeDark;
  static const primaryLight = orangeLight;
  static const primaryPale = orangePale;
  static const onPrimary = white;
  static const surface = offWhite;
  static const surfaceCard = white;
  static const onSurface = black;
  static const onSurfaceVariant = darkGray;
  static const outline = gray;
  static const background = offWhite;

  // ─── Status Colors (Orange tints only) ──────────────────────
  static const statusPending = Color(0xFFFFD9C2);
  static const statusAssigned = orangeLight;
  static const statusAccepted = orange;
  static const statusPickedUp = orangeDark;
  static const statusInTransit = orange;
  static const statusDelivered = Color(0xFF4CAF50); // only for delivered success
  static const statusCancelled = Color(0xFFE0E0E0);

  // ─── Legacy aliases ─────────────────────────────────────────
  static const primaryStart = orange;
  static const primaryEnd = orangeDark;
  static const accentGreen = Color(0xFF4CAF50);
  static const accentRed = Color(0xFFE53935);
  static const accentOrange = orange;
  static const accentBlue = orange;
  static const backgroundLight = offWhite;

  // ─── Gradients ──────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [orange, orangeDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient whiteGradient = LinearGradient(
    colors: [white, offWhite],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ─── Soft Shadow ────────────────────────────────────────────
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: orange.withValues(alpha: 0.1),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}
