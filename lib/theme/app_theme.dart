import 'package:flutter/material.dart';
import 'app_colors.dart';

/// SwiftDrop Theme — Orange & White Only
class AppTheme {
  static const String _fontFamily = 'Inter';

  // ─── Dark / Black Theme ────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: _fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.orange,
        brightness: Brightness.dark,
        primary: AppColors.orange,
        onPrimary: AppColors.white,
        primaryContainer: AppColors.orangeDark,
        onPrimaryContainer: AppColors.white,
        secondary: AppColors.orangeLight,
        onSecondary: AppColors.white,
        secondaryContainer: AppColors.orangeDark,
        onSecondaryContainer: AppColors.white,
        tertiary: AppColors.orange,
        onTertiary: AppColors.white,
        tertiaryContainer: AppColors.orangeDark,
        onTertiaryContainer: AppColors.white,
        surface: const Color(0xFF121212),
        onSurface: Colors.white,
        onSurfaceVariant: const Color(0xFFB0B0B0),
        error: AppColors.orangeDark,
        onError: AppColors.white,
        errorContainer: AppColors.orangeDark,
        outline: const Color(0xFF2C2C2C),
        outlineVariant: const Color(0xFF3A3A3A),
      ),
      scaffoldBackgroundColor: const Color(0xFF0A0A0A),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.2, color: Colors.white, decoration: TextDecoration.none),
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.3, height: 1.2, color: Colors.white, decoration: TextDecoration.none),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.3, color: Colors.white, decoration: TextDecoration.none),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, height: 1.4, color: Colors.white, decoration: TextDecoration.none),
        bodyLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.4, color: Colors.white, decoration: TextDecoration.none),
        bodyMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.3, color: Color(0xFFB0B0B0), decoration: TextDecoration.none),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.3, color: Colors.white, decoration: TextDecoration.none),
        labelLarge: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.3, letterSpacing: 0.3, color: Colors.white, decoration: TextDecoration.none),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: AppColors.white,
          minimumSize: const Size(double.infinity, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
          textStyle: const TextStyle(fontFamily: _fontFamily, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.orange,
          minimumSize: const Size(double.infinity, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          side: const BorderSide(color: AppColors.orange, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontFamily: _fontFamily, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.orange, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.orangeDark)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.orangeDark, width: 2)),
        labelStyle: const TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFB0B0B0)),
        hintStyle: TextStyle(fontFamily: _fontFamily, fontSize: 14, color: Colors.white.withValues(alpha: 0.4)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF2C2C2C), width: 1)),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF121212),
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.orange,
        elevation: 0,
        shadowColor: Colors.black26,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(fontFamily: _fontFamily, fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.orange),
        iconTheme: IconThemeData(color: Color(0xFFB0B0B0)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2C2C2C),
        contentTextStyle: const TextStyle(color: Colors.white, fontFamily: _fontFamily),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        height: 80,
        indicatorColor: AppColors.orange.withValues(alpha: 0.15),
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontFamily: _fontFamily, fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.orange);
          }
          return const TextStyle(fontFamily: _fontFamily, fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFFB0B0B0));
        }),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF2C2C2C), thickness: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: const TextStyle(fontFamily: _fontFamily, fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
        contentTextStyle: const TextStyle(fontFamily: _fontFamily, fontSize: 14, color: Color(0xFFB0B0B0)),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.orange,
        brightness: Brightness.light,
        primary: AppColors.orange,
        onPrimary: AppColors.white,
        primaryContainer: AppColors.orange,
        onPrimaryContainer: AppColors.white,
        secondary: AppColors.orangeLight,
        onSecondary: AppColors.white,
        secondaryContainer: AppColors.orangePale,
        onSecondaryContainer: AppColors.charcoal,
        tertiary: AppColors.orangeDark,
        onTertiary: AppColors.white,
        tertiaryContainer: AppColors.orangeDark,
        onTertiaryContainer: AppColors.white,
        surface: AppColors.offWhite,
        onSurface: AppColors.black,
        onSurfaceVariant: AppColors.darkGray,
        error: AppColors.orangeDark,
        onError: AppColors.white,
        errorContainer: AppColors.orangePale,
        outline: AppColors.gray,
        outlineVariant: AppColors.orangePale,
      ),
      scaffoldBackgroundColor: AppColors.offWhite,
      fontFamily: _fontFamily,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.2, color: AppColors.black, decoration: TextDecoration.none),
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.3, height: 1.2, color: AppColors.black, decoration: TextDecoration.none),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.3, color: AppColors.black, decoration: TextDecoration.none),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, height: 1.4, color: AppColors.black, decoration: TextDecoration.none),
        bodyLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.4, color: AppColors.black, decoration: TextDecoration.none),
        bodyMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.3, color: AppColors.darkGray, decoration: TextDecoration.none),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.3, color: AppColors.black, decoration: TextDecoration.none),
        labelLarge: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.3, letterSpacing: 0.3, color: AppColors.black, decoration: TextDecoration.none),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: AppColors.white,
          minimumSize: const Size(double.infinity, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
          textStyle: const TextStyle(fontFamily: _fontFamily, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.orange,
          minimumSize: const Size(double.infinity, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          side: const BorderSide(color: AppColors.orange, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontFamily: _fontFamily, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightGray,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.orange, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.orangeDark)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.orangeDark, width: 2)),
        labelStyle: const TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.darkGray),
        hintStyle: TextStyle(fontFamily: _fontFamily, fontSize: 14, color: AppColors.darkGray.withValues(alpha: 0.6)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.gray, width: 1)),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.orange,
        elevation: 0,
        shadowColor: Colors.black12,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(fontFamily: _fontFamily, fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.orange),
        iconTheme: IconThemeData(color: AppColors.darkGray),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.white,
        elevation: 0,
        height: 80,
        indicatorColor: AppColors.orange.withValues(alpha: 0.1),
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontFamily: _fontFamily, fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.orange);
          }
          return const TextStyle(fontFamily: _fontFamily, fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.darkGray);
        }),
      ),
    );
  }
}
