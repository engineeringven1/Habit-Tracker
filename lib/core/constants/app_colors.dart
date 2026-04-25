import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Background colours — mutable so palettes can swap them
  static Color backgroundBase  = const Color(0xFF0A0A0F);
  static Color surfaceCard     = const Color(0xFF12121A);
  static Color surfaceElevated = const Color(0xFF1A1A26);

  // Accent colours — mutable
  static Color primaryAccent   = const Color(0xFF7C3AED);
  static Color secondaryAccent = const Color(0xFF06B6D4);

  // Fixed semantic colours
  static const Color successColor  = Color(0xFF10B981);
  static const Color warningColor  = Color(0xFFF59E0B);
  static const Color dangerColor   = Color(0xFFEF4444);

  // Text colours — mutable for light/dark mode
  static Color textPrimary   = const Color(0xFFF8F8FF);
  static Color textSecondary = const Color(0xFF94A3B8);

  // Gradients — mutable accents, fixed others
  static List<Color> gradientPrimary = const [Color(0xFF7C3AED), Color(0xFF4F46E5)];
  static List<Color> gradientAccent  = const [Color(0xFF06B6D4), Color(0xFF0891B2)];
  static const List<Color> gradientSuccess = [Color(0xFF10B981), Color(0xFF059669)];
  static List<Color> get gradientCard =>
      [surfaceElevated, surfaceCard]; // always tracks current surface
}
