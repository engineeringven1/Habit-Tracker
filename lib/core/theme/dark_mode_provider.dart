import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import 'palette_provider.dart';

class DarkModeNotifier extends Notifier<bool> {
  static const _key = 'is_dark_mode';

  // Light-mode overrides (accents stay from the palette)
  static const _lightBg       = Color(0xFFF0F2F5);
  static const _lightCard     = Color(0xFFFFFFFF);
  static const _lightElevated = Color(0xFFE2E8F0);
  static const _lightText     = Color(0xFF1E293B);
  static const _lightTextSec  = Color(0xFF64748B);

  @override
  bool build() {
    _load();
    return true; // default: dark
  }

  void _load() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_key) ?? true;
    currentIsDark = isDark;
    if (!isDark) {
      _applyLight();
      state = false;
    }
  }

  void toggle() async {
    final newDark = !state;
    currentIsDark = newDark;
    state = newDark;
    if (newDark) {
      final palette = ref.read(paletteProvider);
      AppColors.backgroundBase  = palette.backgroundBase;
      AppColors.surfaceCard     = palette.surfaceCard;
      AppColors.surfaceElevated = palette.surfaceElevated;
      AppColors.textPrimary     = const Color(0xFFF8F8FF);
      AppColors.textSecondary   = const Color(0xFF94A3B8);
    } else {
      _applyLight();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, newDark);
  }

  void _applyLight() {
    AppColors.backgroundBase  = _lightBg;
    AppColors.surfaceCard     = _lightCard;
    AppColors.surfaceElevated = _lightElevated;
    AppColors.textPrimary     = _lightText;
    AppColors.textSecondary   = _lightTextSec;
  }
}

final darkModeProvider = NotifierProvider<DarkModeNotifier, bool>(
  DarkModeNotifier.new,
);
