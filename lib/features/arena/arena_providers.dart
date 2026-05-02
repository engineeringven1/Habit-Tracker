import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/habit.dart';
import '../stats/stats_providers.dart';
import '../tracker/tracker_providers.dart';

// ─── Level System ─────────────────────────────────────────────────────────────

const _levelData = <(String, int, int)>[
  ('Curioso',    0,      500),
  ('Aprendiz',   500,    1500),
  ('Filósofo',   1500,   3500),
  ('Estoico',    3500,   7000),
  ('Sabio',      7000,   12000),
  ('Maestro',    12000,  20000),
  ('Inmutable',  20000,  -1),
];

typedef ArenaLevel = ({int index, String name, int min, int max});

ArenaLevel levelForPoints(int pts) {
  for (int i = _levelData.length - 1; i >= 0; i--) {
    if (pts >= _levelData[i].$2) {
      return (index: i, name: _levelData[i].$1, min: _levelData[i].$2, max: _levelData[i].$3);
    }
  }
  return (index: 0, name: 'Curioso', min: 0, max: 500);
}

Color levelColor(int index) {
  const colors = [
    Color(0xFF9E9E9E),
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFF9C27B0),
    Color(0xFFFF9800),
    Color(0xFFE91E63),
    Color(0xFFFFD700),
  ];
  return colors[index.clamp(0, colors.length - 1)];
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _parseDate(String s) {
  final p = s.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

String _mondayOf(DateTime d) {
  final m = d.subtract(Duration(days: d.weekday - 1));
  return _fmt(DateTime(m.year, m.month, m.day));
}

// ─── Points Calculation ───────────────────────────────────────────────────────

int _computeBasePoints({
  required List<Map<String, dynamic>> logs,
  required List<Habit> habits,
}) {
  if (habits.isEmpty || logs.isEmpty) return 0;
  final today = DateTime.now();

  final completedSet = <String>{};
  final earlySet = <String>{}; // before 7am

  for (final l in logs) {
    if (l['completed'] != true) continue;
    final key = '${l['habit_id']}_${l['log_date']}';
    completedSet.add(key);
    final cat = l['completed_at'];
    if (cat != null) {
      try {
        final dt = DateTime.parse(cat as String).toLocal();
        if (dt.hour < 7) earlySet.add(key);
      } catch (_) {}
    }
  }

  int pts = completedSet.length * 10;
  pts += earlySet.length * 20;

  // Daily bonuses
  final days = <String>{};
  for (final l in logs) { days.add(l['log_date'] as String); }
  for (final ds in days) {
    final date = _parseDate(ds);
    final scheduled = habits.where((h) => h.daysOfWeek.contains(date.weekday)).toList();
    if (scheduled.isEmpty) continue;
    int done = 0;
    for (final h in scheduled) {
      if (completedSet.contains('${h.id}_$ds')) done++;
    }
    final pct = done / scheduled.length;
    if (pct >= 1.0) {
      pts += 150;
    } else if (pct >= 0.7) {
      pts += 50;
    }
  }

  // Streak milestones +200 (7 days) +500 (21 days)
  for (final h in habits) {
    int streak = 0;
    for (int i = 363; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      if (!h.daysOfWeek.contains(date.weekday)) continue;
      final ds = _fmt(date);
      if (completedSet.contains('${h.id}_$ds')) {
        streak++;
        if (streak == 7) pts += 200;
        if (streak == 21) pts += 500;
      } else {
        streak = 0;
      }
    }
  }

  return pts;
}

// ─── Achievement Definitions ──────────────────────────────────────────────────

class AchievementDef {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final int bonusPts;

  const AchievementDef({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.bonusPts,
  });
}

const kAchievements = <AchievementDef>[
  AchievementDef(id: 'streak_7',    name: 'Primera semana',    description: 'Consigue una racha de 7 días en cualquier hábito',              icon: Icons.whatshot_rounded,           bonusPts: 200),
  AchievementDef(id: 'streak_30',   name: 'Mes de hierro',     description: 'Consigue una racha de 30 días en cualquier hábito',             icon: Icons.fitness_center_rounded,     bonusPts: 500),
  AchievementDef(id: 'streak_66',   name: 'Los 66',            description: 'Consigue una racha de 66 días en cualquier hábito',             icon: Icons.local_fire_department,      bonusPts: 1000),
  AchievementDef(id: 'streak_100',  name: 'Centurión',         description: 'Consigue una racha de 100 días en cualquier hábito',            icon: Icons.military_tech_rounded,      bonusPts: 2000),
  AchievementDef(id: 'early_10',    name: 'Madrugador',        description: 'Completa algún hábito antes de las 6am en 10 ocasiones',        icon: Icons.wb_twilight_rounded,        bonusPts: 300),
  AchievementDef(id: 'early_21',    name: 'Guardia de alba',   description: '21 días seguidos con algún hábito completado antes de las 6am', icon: Icons.nightlight_round,           bonusPts: 800),
  AchievementDef(id: 'sin_veneno',  name: 'Sin veneno',        description: '14 días sin fallar ningún hábito de categoría Restricción',     icon: Icons.block_rounded,              bonusPts: 400),
  AchievementDef(id: 'cocina',      name: 'Cocina propia',     description: 'Completa hábitos de Nutrición 30 veces',                        icon: Icons.restaurant_rounded,         bonusPts: 600),
  AchievementDef(id: 'perfecto',    name: 'Perfecto',          description: 'Primer día con el 100% de hábitos completados',                 icon: Icons.stars_rounded,              bonusPts: 300),
  AchievementDef(id: 'elite_week',  name: 'Semana élite',      description: '7 días seguidos con ≥80% de cumplimiento',                     icon: Icons.workspace_premium_rounded,  bonusPts: 700),
  AchievementDef(id: 'consistent',  name: 'Consistente',       description: '30 días con ≥70% de cumplimiento',                             icon: Icons.verified_rounded,           bonusPts: 800),
  AchievementDef(id: 'no_excuses',  name: 'Sin excusas',       description: 'Al menos 1 hábito completado en 30 días consecutivos',         icon: Icons.shield_rounded,             bonusPts: 500),
  AchievementDef(id: 'multidim',    name: 'Multidimensional',  description: 'Todas las categorías >50% en la misma semana',                 icon: Icons.hub_rounded,                bonusPts: 600),
  AchievementDef(id: 'estoico_ach', name: 'El estoico',        description: 'Retoma un hábito al día siguiente de fallarlo, 5 veces',       icon: Icons.replay_rounded,             bonusPts: 400),
  AchievementDef(id: 'architect',   name: 'Arquitecto',        description: 'Ten 20 hábitos activos simultáneamente',                       icon: Icons.account_tree_rounded,       bonusPts: 300),
  AchievementDef(id: 'autodidact',  name: 'Autodidacta',       description: 'Haz 10 preguntas al chat del Mentor',                          icon: Icons.psychology_alt_rounded,     bonusPts: 200),
];

class AchievementStatus {
  final AchievementDef def;
  final bool unlocked;
  final String? unlockedDate;
  final String progressHint;

  const AchievementStatus({
    required this.def,
    required this.unlocked,
    this.unlockedDate,
    this.progressHint = '',
  });
}

List<AchievementStatus> _computeAchievements({
  required List<Map<String, dynamic>> logs,
  required List<Habit> habits,
  required int chatCount,
  required Map<String, String> unlocks,
}) {
  final today = DateTime.now();
  final todayStr = _fmt(today);

  final completedSet = <String>{};
  final failedSet = <String>{};

  for (final l in logs) {
    final key = '${l['habit_id']}_${l['log_date']}';
    if (l['completed'] == true) completedSet.add(key);
    if (l['manually_failed'] == true) failedSet.add(key);
  }

  // Early completions (before 6am) – per day set
  final earlyDaySet = <String>{};
  for (final l in logs) {
    if (l['completed'] != true) continue;
    final cat = l['completed_at'];
    if (cat == null) continue;
    try {
      final dt = DateTime.parse(cat as String).toLocal();
      if (dt.hour < 6) earlyDaySet.add(l['log_date'] as String);
    } catch (_) {}
  }
  final earlyCount = earlyDaySet.length;

  // Best streak across all habits
  int bestStreak = 0;
  for (final h in habits) {
    int streak = 0;
    int maxStreak = 0;
    for (int i = 363; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      if (!h.daysOfWeek.contains(date.weekday)) continue;
      if (completedSet.contains('${h.id}_${_fmt(date)}')) {
        streak++;
        if (streak > maxStreak) maxStreak = streak;
      } else {
        streak = 0;
      }
    }
    if (maxStreak > bestStreak) bestStreak = maxStreak;
  }

  AchievementStatus check(String id, bool condition, String hint) {
    final def = kAchievements.firstWhere((a) => a.id == id);
    if (condition || unlocks.containsKey(id)) {
      unlocks[id] ??= todayStr;
      return AchievementStatus(def: def, unlocked: true, unlockedDate: unlocks[id]);
    }
    return AchievementStatus(def: def, unlocked: false, progressHint: hint);
  }

  final result = <AchievementStatus>[
    // Rachas
    check('streak_7',   bestStreak >= 7,   'Te faltan ${(7 - bestStreak).clamp(0, 7)} días de racha'),
    check('streak_30',  bestStreak >= 30,  'Te faltan ${(30 - bestStreak).clamp(0, 30)} días de racha'),
    check('streak_66',  bestStreak >= 66,  'Te faltan ${(66 - bestStreak).clamp(0, 66)} días de racha'),
    check('streak_100', bestStreak >= 100, 'Te faltan ${(100 - bestStreak).clamp(0, 100)} días de racha'),
  ];

  // Early_10 – count early days
  result.add(check('early_10', earlyCount >= 10,
      'Te faltan ${(10 - earlyCount).clamp(0, 10)} mañanas antes de las 6am'));

  // Early_21 – 21 consecutive days with early completion
  {
    int earlyStreak = 0, maxEarlyStreak = 0;
    for (int i = 363; i >= 0; i--) {
      final ds = _fmt(today.subtract(Duration(days: i)));
      if (earlyDaySet.contains(ds)) {
        earlyStreak++;
        if (earlyStreak > maxEarlyStreak) maxEarlyStreak = earlyStreak;
      } else {
        earlyStreak = 0;
      }
    }
    result.add(check('early_21', maxEarlyStreak >= 21,
        'Te faltan ${(21 - maxEarlyStreak).clamp(0, 21)} días consecutivos antes de las 6am'));
  }

  // Sin_veneno – 14 consecutive days without failing restricción habits
  {
    final restrict = habits.where((h) => h.category.toLowerCase().contains('restricc')).toList();
    if (restrict.isEmpty) {
      result.add(AchievementStatus(
        def: kAchievements.firstWhere((a) => a.id == 'sin_veneno'),
        unlocked: false,
        progressHint: 'Necesitas hábitos en la categoría Restricción',
      ));
    } else {
      int clean = 0, maxClean = 0;
      for (int i = 363; i >= 0; i--) {
        final ds = _fmt(today.subtract(Duration(days: i)));
        if (restrict.any((h) => failedSet.contains('${h.id}_$ds'))) {
          clean = 0;
        } else {
          clean++;
          if (clean > maxClean) maxClean = clean;
        }
      }
      result.add(check('sin_veneno', maxClean >= 14,
          'Te faltan ${(14 - maxClean).clamp(0, 14)} días sin fallos en Restricción'));
    }
  }

  // Cocina – nutrición completions 30 times
  {
    final nutriIds = habits.where((h) => h.category.toLowerCase().contains('nutri')).map((h) => h.id).toSet();
    final nutriCount = logs.where((l) => l['completed'] == true && nutriIds.contains(l['habit_id'])).length;
    result.add(check('cocina', nutriCount >= 30,
        'Te faltan ${(30 - nutriCount).clamp(0, 30)} completaciones en Nutrición'));
  }

  // Perfecto – first perfect day
  {
    bool hasPerfect = false;
    if (!unlocks.containsKey('perfecto')) {
      for (int i = 1; i <= 363 && !hasPerfect; i++) {
        final date = today.subtract(Duration(days: i));
        final ds = _fmt(date);
        final scheduled = habits.where((h) => h.daysOfWeek.contains(date.weekday)).toList();
        if (scheduled.isEmpty) continue;
        if (scheduled.every((h) => completedSet.contains('${h.id}_$ds'))) hasPerfect = true;
      }
    }
    result.add(check('perfecto', hasPerfect, 'Completa todos los hábitos en un mismo día'));
  }

  // Elite_week – 7 consecutive days ≥80%
  {
    int eliteStreak = 0, maxElite = 0;
    for (int i = 363; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final ds = _fmt(date);
      final scheduled = habits.where((h) => h.daysOfWeek.contains(date.weekday)).toList();
      if (scheduled.isEmpty) { eliteStreak = 0; continue; }
      final done = scheduled.where((h) => completedSet.contains('${h.id}_$ds')).length;
      if (done / scheduled.length >= 0.8) {
        eliteStreak++;
        if (eliteStreak > maxElite) maxElite = eliteStreak;
      } else {
        eliteStreak = 0;
      }
    }
    result.add(check('elite_week', maxElite >= 7,
        'Te faltan ${(7 - maxElite).clamp(0, 7)} días seguidos con ≥80%'));
  }

  // Consistent – 30 days ≥70% (not necessarily consecutive)
  {
    int count70 = 0;
    for (int i = 1; i <= 363; i++) {
      final date = today.subtract(Duration(days: i));
      final ds = _fmt(date);
      final scheduled = habits.where((h) => h.daysOfWeek.contains(date.weekday)).toList();
      if (scheduled.isEmpty) continue;
      final done = scheduled.where((h) => completedSet.contains('${h.id}_$ds')).length;
      if (done / scheduled.length >= 0.7) count70++;
    }
    result.add(check('consistent', count70 >= 30,
        'Te faltan ${(30 - count70).clamp(0, 30)} días con ≥70%'));
  }

  // No_excuses – at least 1 completion in 30 consecutive days
  {
    int noExStreak = 0, maxNoEx = 0;
    for (int i = 363; i >= 0; i--) {
      final ds = _fmt(today.subtract(Duration(days: i)));
      if (logs.any((l) => l['log_date'] == ds && l['completed'] == true)) {
        noExStreak++;
        if (noExStreak > maxNoEx) maxNoEx = noExStreak;
      } else {
        noExStreak = 0;
      }
    }
    result.add(check('no_excuses', maxNoEx >= 30,
        'Te faltan ${(30 - maxNoEx).clamp(0, 30)} días consecutivos con al menos 1 hábito'));
  }

  // Multidim – all categories >50% in same week
  {
    final categories = habits.map((h) => h.category).toSet().toList();
    bool multidimDone = false;
    if (!unlocks.containsKey('multidim') && categories.isNotEmpty) {
      outer:
      for (int w = 0; w < 52; w++) {
        final weekStart = today.subtract(Duration(days: w * 7 + 6));
        for (final cat in categories) {
          final catHabits = habits.where((h) => h.category == cat).toList();
          int sch = 0, done = 0;
          for (int d = 0; d < 7; d++) {
            final date = weekStart.add(Duration(days: d));
            final ds = _fmt(date);
            for (final h in catHabits) {
              if (!h.daysOfWeek.contains(date.weekday)) continue;
              sch++;
              if (completedSet.contains('${h.id}_$ds')) done++;
            }
          }
          if (sch > 0 && done / sch <= 0.5) continue outer;
        }
        multidimDone = true;
        break;
      }
    }
    result.add(check('multidim', multidimDone,
        'Consigue >50% en todas las categorías en la misma semana'));
  }

  // Estoico – bounce back after fail, 5 times
  {
    int bouncebacks = 0;
    for (final h in habits) {
      for (int i = 362; i >= 1; i--) {
        final ds = _fmt(today.subtract(Duration(days: i)));
        final nextDs = _fmt(today.subtract(Duration(days: i - 1)));
        if (failedSet.contains('${h.id}_$ds') && completedSet.contains('${h.id}_$nextDs')) {
          bouncebacks++;
        }
      }
    }
    result.add(check('estoico_ach', bouncebacks >= 5,
        'Te faltan ${(5 - bouncebacks).clamp(0, 5)} recuperaciones tras fallo'));
  }

  // Architect – 20 active habits
  result.add(check('architect', habits.length >= 20,
      'Te faltan ${(20 - habits.length).clamp(0, 20)} hábitos activos'));

  // Autodidact – 10 mentor chat questions
  result.add(check('autodidact', chatCount >= 10,
      'Te faltan ${(10 - chatCount).clamp(0, 10)} preguntas al Mentor'));

  return result;
}

// ─── Identity Stats ───────────────────────────────────────────────────────────

class IdentityStats {
  final double recoveryRateDays;
  final String? peakHour;
  final String? dominantCategory;
  final String? longestStreakHabit;
  final int longestStreakDays;
  final int totalCompletions;
  final int activeDays;

  const IdentityStats({
    required this.recoveryRateDays,
    required this.peakHour,
    required this.dominantCategory,
    required this.longestStreakHabit,
    required this.longestStreakDays,
    required this.totalCompletions,
    required this.activeDays,
  });
}

IdentityStats _computeIdentityStats({
  required List<Map<String, dynamic>> logs,
  required List<Habit> habits,
}) {
  final today = DateTime.now();

  final totalCompletions = logs.where((l) => l['completed'] == true).length;

  final activeDaySet = <String>{};
  for (final l in logs) {
    if (l['completed'] == true) activeDaySet.add(l['log_date'] as String);
  }

  // Peak hour bucket
  final hourBuckets = List.filled(24, 0);
  for (final l in logs) {
    if (l['completed'] != true) continue;
    final cat = l['completed_at'];
    if (cat == null) continue;
    try {
      final dt = DateTime.parse(cat as String).toLocal();
      hourBuckets[dt.hour]++;
    } catch (_) {}
  }
  String? peakHour;
  int maxCount = 0;
  for (int i = 0; i < 24; i++) {
    if (hourBuckets[i] > maxCount) {
      maxCount = hourBuckets[i];
      peakHour = '${i.toString().padLeft(2, '0')}:00–${(i + 1).toString().padLeft(2, '0')}:00';
    }
  }
  if (maxCount == 0) peakHour = null;

  // Dominant category (highest 30-day rate)
  final completedSet = <String>{};
  for (final l in logs) {
    if (l['completed'] == true) completedSet.add('${l['habit_id']}_${l['log_date']}');
  }
  String? dominantCategory;
  double bestRate = 0;
  final catGroups = <String, List<Habit>>{};
  for (final h in habits) {
    catGroups.putIfAbsent(h.category, () => []).add(h);
  }
  for (final entry in catGroups.entries) {
    int sch = 0, done = 0;
    for (int i = 1; i <= 30; i++) {
      final date = today.subtract(Duration(days: i));
      final ds = _fmt(date);
      for (final h in entry.value) {
        if (!h.daysOfWeek.contains(date.weekday)) continue;
        sch++;
        if (completedSet.contains('${h.id}_$ds')) done++;
      }
    }
    final rate = sch == 0 ? 0.0 : done / sch;
    if (rate > bestRate) {
      bestRate = rate;
      dominantCategory = entry.key;
    }
  }

  // Longest current streak
  String? longestHabit;
  int longestDays = 0;
  for (final h in habits) {
    int streak = 0;
    for (int i = 0; i < 364; i++) {
      final date = today.subtract(Duration(days: i));
      if (!h.daysOfWeek.contains(date.weekday)) continue;
      final ds = _fmt(date);
      if (completedSet.contains('${h.id}_$ds')) {
        streak++;
      } else if (i == 0) {
        continue;
      } else {
        break;
      }
    }
    if (streak > longestDays) {
      longestDays = streak;
      longestHabit = h.name;
    }
  }

  // Recovery rate – avg days to resume after manual fail
  double totalRecovery = 0;
  int recoveryCount = 0;
  final failedSet = <String>{};
  for (final l in logs) {
    if (l['manually_failed'] == true) failedSet.add('${l['habit_id']}_${l['log_date']}');
  }
  for (final h in habits) {
    for (int i = 362; i >= 1; i--) {
      final ds = _fmt(today.subtract(Duration(days: i)));
      if (!failedSet.contains('${h.id}_$ds')) continue;
      for (int j = 1; j <= 7; j++) {
        final nextDs = _fmt(today.subtract(Duration(days: i - j)));
        if (completedSet.contains('${h.id}_$nextDs')) {
          totalRecovery += j;
          recoveryCount++;
          break;
        }
      }
    }
  }

  return IdentityStats(
    recoveryRateDays: recoveryCount == 0 ? 0 : totalRecovery / recoveryCount,
    peakHour: peakHour,
    dominantCategory: dominantCategory,
    longestStreakHabit: longestHabit,
    longestStreakDays: longestDays,
    totalCompletions: totalCompletions,
    activeDays: activeDaySet.length,
  );
}

// ─── Weekly Challenges ────────────────────────────────────────────────────────

class ChallengeDef {
  final String id;
  final String description;
  final int target;
  final int bonusPts;

  const ChallengeDef({
    required this.id,
    required this.description,
    required this.target,
    required this.bonusPts,
  });
}

const _challengePool = <ChallengeDef>[
  ChallengeDef(id: 'perfect_2',        description: 'Logra 2 días perfectos esta semana',                          target: 2,  bonusPts: 500),
  ChallengeDef(id: 'perfect_1',        description: 'Logra un día perfecto (100%) esta semana',                    target: 1,  bonusPts: 300),
  ChallengeDef(id: 'early_3',          description: 'Completa algún hábito antes de las 6am por 3 días',           target: 3,  bonusPts: 350),
  ChallengeDef(id: 'early_7',          description: 'Completa algún hábito antes de las 7am los 7 días',           target: 7,  bonusPts: 500),
  ChallengeDef(id: 'pct70_5',          description: 'Logra ≥70% de cumplimiento 5 días seguidos',                  target: 5,  bonusPts: 450),
  ChallengeDef(id: 'pct70_7',          description: 'Logra ≥70% de cumplimiento los 7 días',                       target: 7,  bonusPts: 550),
  ChallengeDef(id: 'pct80_3',          description: 'Logra ≥80% en 3 días esta semana',                            target: 3,  bonusPts: 300),
  ChallengeDef(id: 'active_7',         description: 'Al menos 1 hábito completado cada día de la semana',          target: 7,  bonusPts: 350),
  ChallengeDef(id: 'streak_3',         description: 'Mantén una racha de 3 días en cualquier hábito',              target: 3,  bonusPts: 200),
  ChallengeDef(id: 'streak_5',         description: 'Mantén una racha de 5 días en cualquier hábito',              target: 5,  bonusPts: 400),
  ChallengeDef(id: '7_day_habit',      description: 'Completa el mismo hábito los 7 días de la semana',            target: 7,  bonusPts: 400),
  ChallengeDef(id: 'no_restrict_fail', description: 'No falles ningún hábito de Restricción esta semana',          target: 7,  bonusPts: 400),
  ChallengeDef(id: 'no_double_fail',   description: 'No falles el mismo hábito dos veces seguidas',                target: 7,  bonusPts: 300),
  ChallengeDef(id: 'health_all',       description: 'Completa todos los hábitos de Salud cada día que aplique',    target: 7,  bonusPts: 350),
  ChallengeDef(id: 'nutrition_5',      description: 'Completa hábitos de Nutrición al menos 5 veces',              target: 5,  bonusPts: 300),
  ChallengeDef(id: 'discipline_5',     description: 'Completa hábitos de Disciplina al menos 5 veces',             target: 5,  bonusPts: 300),
  ChallengeDef(id: 'morning_5',        description: 'Completa algún hábito antes de las 8am por 5 días',           target: 5,  bonusPts: 300),
  ChallengeDef(id: 'mind_5',           description: 'Completa hábitos de Mente al menos 5 veces',                  target: 5,  bonusPts: 350),
  ChallengeDef(id: 'work_5',           description: 'Completa hábitos de Trabajo al menos 5 veces',                target: 5,  bonusPts: 350),
  ChallengeDef(id: 'finance_5',        description: 'Completa hábitos de Finanzas al menos 5 veces',               target: 5,  bonusPts: 300),
];

class WeeklyChallenge {
  final ChallengeDef def;
  final int current;
  final bool completed;
  final bool pointsAwarded;
  final int daysLeft;

  const WeeklyChallenge({
    required this.def,
    required this.current,
    required this.completed,
    required this.pointsAwarded,
    required this.daysLeft,
  });
}

List<ChallengeDef> _pickChallenges(String mondayStr, List<String> lastWeekIds) {
  final seed = mondayStr.replaceAll('-', '').hashCode;
  final rng = Random(seed);
  final pool = List<ChallengeDef>.from(
    _challengePool.where((c) => !lastWeekIds.contains(c.id)),
  );
  if (pool.length < 3) {
    final fallback = List<ChallengeDef>.from(_challengePool)..shuffle(rng);
    return fallback.take(3).toList();
  }
  pool.shuffle(rng);
  return pool.take(3).toList();
}

List<WeeklyChallenge> _computeChallengeProgress({
  required List<ChallengeDef> challenges,
  required List<Map<String, dynamic>> weekLogs,
  required List<Habit> habits,
  required DateTime monday,
  required List<String> awardedIds,
}) {
  final today = DateTime.now();
  final sunday = monday.add(const Duration(days: 6));
  final daysLeft = sunday.difference(DateTime(today.year, today.month, today.day)).inDays.clamp(0, 7);

  final completedSet = <String>{};
  for (final l in weekLogs) {
    if (l['completed'] == true) completedSet.add('${l['habit_id']}_${l['log_date']}');
  }

  int dayPct(String ds, int weekday) {
    final scheduled = habits.where((h) => h.daysOfWeek.contains(weekday)).toList();
    if (scheduled.isEmpty) return -1;
    final done = scheduled.where((h) => completedSet.contains('${h.id}_$ds')).length;
    return (done / scheduled.length * 100).round();
  }

  return challenges.map((c) {
    int current = 0;

    if (c.id == 'perfect_2' || c.id == 'perfect_1') {
      for (int i = 0; i < 7; i++) {
        final date = monday.add(Duration(days: i));
        if (date.isAfter(today)) break;
        if (dayPct(_fmt(date), date.weekday) == 100) current++;
      }
    } else if (c.id == 'pct70_5') {
      int streak = 0;
      for (int i = 0; i < 7; i++) {
        final date = monday.add(Duration(days: i));
        if (date.isAfter(today)) break;
        final pct = dayPct(_fmt(date), date.weekday);
        if (pct >= 70) {
          streak++;
          if (streak > current) current = streak;
        } else {
          streak = 0;
        }
      }
    } else if (c.id == 'pct70_7' || c.id == 'pct80_3') {
      final threshold = c.id == 'pct70_7' ? 70 : 80;
      for (int i = 0; i < 7; i++) {
        final date = monday.add(Duration(days: i));
        if (date.isAfter(today)) break;
        if (dayPct(_fmt(date), date.weekday) >= threshold) current++;
      }
    } else if (c.id == 'active_7') {
      for (int i = 0; i < 7; i++) {
        final date = monday.add(Duration(days: i));
        if (date.isAfter(today)) break;
        final ds = _fmt(date);
        if (weekLogs.any((l) => l['log_date'] == ds && l['completed'] == true)) current++;
      }
    } else if (c.id == 'early_3' || c.id == 'early_7' || c.id == 'morning_5') {
      final hourLimit = c.id == 'morning_5' ? 8 : (c.id == 'early_7' ? 7 : 6);
      final earlyDays = <String>{};
      for (final l in weekLogs) {
        if (l['completed'] != true) continue;
        final cat = l['completed_at'];
        if (cat == null) continue;
        try {
          final dt = DateTime.parse(cat as String).toLocal();
          if (dt.hour < hourLimit) earlyDays.add(l['log_date'] as String);
        } catch (_) {}
      }
      current = earlyDays.length;
    } else if (c.id == 'streak_3' || c.id == 'streak_5') {
      final target = c.id == 'streak_3' ? 3 : 5;
      for (final h in habits) {
        int streak = 0;
        for (int i = 0; i < 7; i++) {
          final date = monday.add(Duration(days: i));
          if (date.isAfter(today)) break;
          if (!h.daysOfWeek.contains(date.weekday)) continue;
          if (completedSet.contains('${h.id}_${_fmt(date)}')) {
            streak++;
          } else {
            streak = 0;
          }
        }
        if (streak > current) current = streak.clamp(0, target);
      }
    } else if (c.id == '7_day_habit') {
      for (final h in habits) {
        int count = 0;
        for (int i = 0; i < 7; i++) {
          final date = monday.add(Duration(days: i));
          if (date.isAfter(today)) break;
          if (!h.daysOfWeek.contains(date.weekday)) continue;
          if (completedSet.contains('${h.id}_${_fmt(date)}')) count++;
        }
        if (count > current) current = count;
      }
    } else if (c.id == 'no_restrict_fail') {
      final restrict = habits.where((h) => h.category.toLowerCase().contains('restricc')).toList();
      if (restrict.isEmpty) {
        current = 0;
      } else {
        for (int i = 0; i < 7; i++) {
          final date = monday.add(Duration(days: i));
          if (date.isAfter(today)) break;
          final ds = _fmt(date);
          final anyFailed = restrict.any((h) =>
              weekLogs.any((l) => l['habit_id'] == h.id && l['log_date'] == ds && l['manually_failed'] == true));
          if (!anyFailed) current++;
        }
      }
    } else if (c.id == 'no_double_fail') {
      bool hasFailed = false;
      outer:
      for (final h in habits) {
        for (int i = 0; i < 6; i++) {
          final d1 = _fmt(monday.add(Duration(days: i)));
          final d2 = _fmt(monday.add(Duration(days: i + 1)));
          final f1 = weekLogs.any((l) => l['habit_id'] == h.id && l['log_date'] == d1 && l['manually_failed'] == true);
          final f2 = weekLogs.any((l) => l['habit_id'] == h.id && l['log_date'] == d2 && l['manually_failed'] == true);
          if (f1 && f2) {
            hasFailed = true;
            break outer;
          }
        }
      }
      current = hasFailed ? 0 : today.difference(monday).inDays.clamp(0, 7);
    } else if (c.id == 'health_all') {
      final healthH = habits.where((h) => h.category.toLowerCase() == 'salud').toList();
      if (healthH.isEmpty) {
        current = 0;
      } else {
        for (int i = 0; i < 7; i++) {
          final date = monday.add(Duration(days: i));
          if (date.isAfter(today)) break;
          final ds = _fmt(date);
          final sch = healthH.where((h) => h.daysOfWeek.contains(date.weekday)).toList();
          if (sch.isEmpty || sch.every((h) => completedSet.contains('${h.id}_$ds'))) current++;
        }
      }
    } else {
      final catKey = {
        'nutrition_5': 'nutrición', 'discipline_5': 'disciplina',
        'mind_5': 'mente', 'work_5': 'trabajo', 'finance_5': 'finanzas',
      }[c.id];
      if (catKey != null) {
        final ids = habits.where((h) => h.category.toLowerCase() == catKey).map((h) => h.id).toSet();
        current = weekLogs.where((l) => l['completed'] == true && ids.contains(l['habit_id'])).length;
      }
    }

    final done = current >= c.target;
    return WeeklyChallenge(
      def: c,
      current: current.clamp(0, c.target),
      completed: done,
      pointsAwarded: awardedIds.contains(c.id),
      daysLeft: daysLeft,
    );
  }).toList();
}

// ─── Arena Data ───────────────────────────────────────────────────────────────

class ArenaData {
  final int totalPoints;
  final ArenaLevel level;
  final List<AchievementStatus> achievements;
  final IdentityStats identityStats;
  final List<WeeklyChallenge> weeklyChallenges;

  const ArenaData({
    required this.totalPoints,
    required this.level,
    required this.achievements,
    required this.identityStats,
    required this.weeklyChallenges,
  });
}

// ─── Chat Count Provider ──────────────────────────────────────────────────────

class _ChatCountNotifier extends StateNotifier<int> {
  static const _key = 'arena_chat_count';

  _ChatCountNotifier() : super(0) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getInt(_key) ?? 0;
  }

  Future<void> increment() async {
    state++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, state);
  }
}

final arenaChatCountProvider =
    StateNotifierProvider<_ChatCountNotifier, int>((_) => _ChatCountNotifier());

// ─── Arena Data Provider ──────────────────────────────────────────────────────

final arenaDataProvider = FutureProvider<ArenaData>((ref) async {
  final logs = await ref.watch(allLogsProvider.future);
  final habits = await ref.watch(habitsProvider.future);
  final chatCount = ref.watch(arenaChatCountProvider);

  final prefs = await SharedPreferences.getInstance();
  final today = DateTime.now();
  final todayStr = _fmt(today);
  final mondayStr = _mondayOf(today);

  // Load saved unlocks (mutated in-place by _computeAchievements)
  final unlocksJson = prefs.getString('arena_unlocked_achievements') ?? '{}';
  final unlocks = Map<String, String>.from(
    (jsonDecode(unlocksJson) as Map).cast<String, String>(),
  );

  // Load weekly challenges state
  final challengeJson = prefs.getString('arena_weekly_challenges') ?? '{}';
  final challengeData = (jsonDecode(challengeJson) as Map).cast<String, dynamic>();

  List<ChallengeDef> weekChallenges;
  List<String> awardedIds;

  if (challengeData['monday'] == mondayStr) {
    final ids = (challengeData['challenges'] as List? ?? []).cast<String>();
    weekChallenges = ids
        .map((id) => _challengePool.firstWhere((c) => c.id == id,
            orElse: () => _challengePool.first))
        .toList();
    awardedIds = (challengeData['awarded'] as List? ?? []).cast<String>();
  } else {
    final lastWeekIds = (challengeData['challenges'] as List? ?? []).cast<String>();
    weekChallenges = _pickChallenges(mondayStr, lastWeekIds);
    awardedIds = [];
  }

  // Current week logs
  final monday = _parseDate(mondayStr);
  final weekEndStr = _fmt(monday.add(const Duration(days: 6)));
  final weekLogs = logs.where((l) {
    final ds = l['log_date'] as String;
    return ds.compareTo(mondayStr) >= 0 && ds.compareTo(weekEndStr) <= 0;
  }).toList();

  // Points
  int pts = _computeBasePoints(logs: logs, habits: habits);

  // Achievements
  final achievements = _computeAchievements(
    logs: logs,
    habits: habits,
    chatCount: chatCount,
    unlocks: unlocks,
  );
  for (final a in achievements) {
    if (a.unlocked) pts += a.def.bonusPts;
  }

  // Challenges progress
  final challenges = _computeChallengeProgress(
    challenges: weekChallenges,
    weekLogs: weekLogs,
    habits: habits,
    monday: monday,
    awardedIds: awardedIds,
  );
  final newAwarded = List<String>.from(awardedIds);
  for (final ch in challenges) {
    if (ch.completed && !awardedIds.contains(ch.def.id)) {
      pts += ch.def.bonusPts;
      newAwarded.add(ch.def.id);
    }
  }

  // Persist
  await prefs.setString('arena_unlocked_achievements', jsonEncode(unlocks));
  await prefs.setString('arena_weekly_challenges', jsonEncode({
    'monday': mondayStr,
    'challenges': weekChallenges.map((c) => c.id).toList(),
    'awarded': newAwarded,
    'last_updated': todayStr,
  }));

  final identityStats = _computeIdentityStats(logs: logs, habits: habits);
  final level = levelForPoints(pts);

  return ArenaData(
    totalPoints: pts,
    level: level,
    achievements: achievements,
    identityStats: identityStats,
    weeklyChallenges: challenges,
  );
});
