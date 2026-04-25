import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';

class PaletteData {
  final String id;
  final String name;
  // Backgrounds
  final Color backgroundBase;
  final Color surfaceCard;
  final Color surfaceElevated;
  // Accents
  final Color primary;
  final Color secondary;
  final List<Color> gradientPrimary;
  final List<Color> gradientAccent;

  const PaletteData({
    required this.id,
    required this.name,
    required this.backgroundBase,
    required this.surfaceCard,
    required this.surfaceElevated,
    required this.primary,
    required this.secondary,
    required this.gradientPrimary,
    required this.gradientAccent,
  });
}

// Shared flag read by PaletteNotifier._apply() and written by DarkModeNotifier.
bool currentIsDark = true;

const List<PaletteData> appPalettes = [
  // 1 ── Cosmos – fondo negro azulado oscuro, violeta/índigo ───────────────────
  PaletteData(
    id: 'cosmos',
    name: 'Cosmos',
    backgroundBase:  Color(0xFF0A0A0F),
    surfaceCard:     Color(0xFF131320),
    surfaceElevated: Color(0xFF1E1E30),
    primary:         Color(0xFF7C3AED),
    secondary:       Color(0xFF06B6D4),
    gradientPrimary: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
    gradientAccent:  [Color(0xFF06B6D4), Color(0xFF0891B2)],
  ),
  // 2 ── Océano – fondo azul marino profundo ────────────────────────────────────
  PaletteData(
    id: 'ocean',
    name: 'Océano',
    backgroundBase:  Color(0xFF060C1A),
    surfaceCard:     Color(0xFF0D1828),
    surfaceElevated: Color(0xFF15253E),
    primary:         Color(0xFF3B82F6),
    secondary:       Color(0xFF06B6D4),
    gradientPrimary: [Color(0xFF3B82F6), Color(0xFF2563EB)],
    gradientAccent:  [Color(0xFF06B6D4), Color(0xFF0891B2)],
  ),
  // 3 ── Esmeralda – fondo verde bosque oscuro ───────────────────────────────────
  PaletteData(
    id: 'emerald',
    name: 'Esmeralda',
    backgroundBase:  Color(0xFF061410),
    surfaceCard:     Color(0xFF0C2018),
    surfaceElevated: Color(0xFF132E22),
    primary:         Color(0xFF10B981),
    secondary:       Color(0xFF14B8A6),
    gradientPrimary: [Color(0xFF10B981), Color(0xFF059669)],
    gradientAccent:  [Color(0xFF14B8A6), Color(0xFF0D9488)],
  ),
  // 4 ── Carmesí – fondo granate oscuro ─────────────────────────────────────────
  PaletteData(
    id: 'crimson',
    name: 'Carmesí',
    backgroundBase:  Color(0xFF160608),
    surfaceCard:     Color(0xFF240C10),
    surfaceElevated: Color(0xFF33121A),
    primary:         Color(0xFFE11D48),
    secondary:       Color(0xFFF97316),
    gradientPrimary: [Color(0xFFE11D48), Color(0xFFBE123C)],
    gradientAccent:  [Color(0xFFF97316), Color(0xFFEA580C)],
  ),
  // 5 ── Ámbar – fondo marrón dorado oscuro ─────────────────────────────────────
  PaletteData(
    id: 'amber',
    name: 'Ámbar',
    backgroundBase:  Color(0xFF140D04),
    surfaceCard:     Color(0xFF221608),
    surfaceElevated: Color(0xFF302010),
    primary:         Color(0xFFF59E0B),
    secondary:       Color(0xFF84CC16),
    gradientPrimary: [Color(0xFFF59E0B), Color(0xFFD97706)],
    gradientAccent:  [Color(0xFF84CC16), Color(0xFF65A30D)],
  ),
];

class PaletteNotifier extends Notifier<PaletteData> {
  static const _prefKey = 'palette_id';

  @override
  PaletteData build() {
    _loadSaved();
    return appPalettes[0];
  }

  void _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_prefKey) ?? 'cosmos';
    final found = appPalettes.where((p) => p.id == id).firstOrNull;
    if (found != null) {
      _apply(found);
      state = found;
    }
  }

  void select(PaletteData palette) async {
    _apply(palette);
    state = palette;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, palette.id);
  }

  void _apply(PaletteData p) {
    // Accent colours always follow the palette
    AppColors.primaryAccent   = p.primary;
    AppColors.secondaryAccent = p.secondary;
    AppColors.gradientPrimary = List.unmodifiable(p.gradientPrimary);
    AppColors.gradientAccent  = List.unmodifiable(p.gradientAccent);

    // Only apply dark backgrounds when in dark mode.
    // Light mode backgrounds are managed by DarkModeNotifier.
    if (currentIsDark) {
      AppColors.backgroundBase  = p.backgroundBase;
      AppColors.surfaceCard     = p.surfaceCard;
      AppColors.surfaceElevated = p.surfaceElevated;
    }
  }
}

final paletteProvider = NotifierProvider<PaletteNotifier, PaletteData>(
  PaletteNotifier.new,
);
