import 'package:flutter/material.dart';

/// Text rendering utilities for crisp, clear text display
class TextUtils {
  /// Creates a TextStyle with optimized rendering for clarity
  static TextStyle crispText({
    required double fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      decoration: TextDecoration.none,
      fontFamily: 'Inter',
      // Optimized for clarity
      textBaseline: TextBaseline.alphabetic,
    );
  }

  /// Heading style with sharp rendering
  static TextStyle heading1({Color? color}) {
    return crispText(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      color: color,
      height: 1.2,
      letterSpacing: -0.5,
    );
  }

  static TextStyle heading2({Color? color}) {
    return crispText(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: color,
      height: 1.2,
      letterSpacing: -0.3,
    );
  }

  static TextStyle heading3({Color? color}) {
    return crispText(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: color,
      height: 1.3,
    );
  }

  /// Body text styles
  static TextStyle body({Color? color}) {
    return crispText(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: color,
      height: 1.4,
    );
  }

  static TextStyle bodyBold({Color? color}) {
    return crispText(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: color,
      height: 1.4,
    );
  }

  static TextStyle caption({Color? color}) {
    return crispText(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: color,
      height: 1.3,
    );
  }

  static TextStyle captionBold({Color? color}) {
    return crispText(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: color,
      height: 1.3,
    );
  }

  /// Button text style
  static TextStyle button({Color? color}) {
    return crispText(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: color,
      height: 1.2,
      letterSpacing: 0.3,
    );
  }

  /// Label style
  static TextStyle label({Color? color}) {
    return crispText(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: color,
      height: 1.3,
      letterSpacing: 0.5,
    );
  }
}
