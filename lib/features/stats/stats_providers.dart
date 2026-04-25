import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/habit.dart';
import '../../data/repositories/stats_repository.dart';
import '../tracker/tracker_providers.dart';

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ─── Repository ───────────────────────────────────────────────────────────────

final statsRepositoryProvider = Provider<StatsRepository>(
  (ref) => StatsRepository(Supabase.instance.client),
);

// ─── 52 weeks chart – only counts scheduled habits per day ───────────────────

final weeklyProgressProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final logs = await ref.watch(allLogsProvider.future);
  final habits = await ref.watch(habitsProvider.future);
  if (habits.isEmpty) return [];

  final today = DateTime.now();
  final weeks = <Map<String, dynamic>>[];

  for (int weekIdx = 51; weekIdx >= 0; weekIdx--) {
    int completed = 0;
    int total = 0;
    final startOffset = weekIdx * 7;

    for (int dayOff = 0; dayOff < 7; dayOff++) {
      final date = today.subtract(Duration(days: startOffset + dayOff));
      final ds = _fmt(date);
      final weekday = date.weekday;

      final scheduledIds = habits
          .where((h) => h.daysOfWeek.contains(weekday))
          .map((h) => h.id)
          .toSet();
      if (scheduledIds.isEmpty) continue;

      final dayLogs = logs
          .where((l) =>
              l['log_date'] == ds && scheduledIds.contains(l['habit_id']))
          .toList();
      if (dayLogs.isNotEmpty) {
        completed += dayLogs.where((l) => l['completed'] == true).length;
        total += scheduledIds.length;
      }
    }

    if (total > 0) {
      weeks.add({
        'week_start': _fmt(today.subtract(Duration(days: startOffset + 6))),
        'completed_count': completed,
        'total_possible': total,
        'score_percentage': (completed / total * 100).roundToDouble(),
      });
    }
  }

  return weeks;
});

// ─── All logs last 364 days (paginated to bypass Supabase 1000-row cap) ───────

final allLogsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser!.id;
  final today = DateTime.now();
  final start = today.subtract(const Duration(days: 363));
  final startStr = _fmt(start);
  final todayStr = _fmt(today);

  final allData = <Map<String, dynamic>>[];
  const pageSize = 1000;
  int from = 0;

  while (true) {
    final data = await client
        .from('daily_logs')
        .select('habit_id, log_date, completed')
        .eq('user_id', userId)
        .gte('log_date', startStr)
        .lte('log_date', todayStr)
        .order('log_date', ascending: false)
        .range(from, from + pageSize - 1);

    final rows = List<Map<String, dynamic>>.from(data as List);
    allData.addAll(rows);
    if (rows.length < pageSize) break;
    from += pageSize;
  }

  return allData;
});

// ─── Recent logs (last 30 days) ───────────────────────────────────────────────

final recentLogsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final logs = await ref.watch(allLogsProvider.future);
  final cutoff = DateTime.now().subtract(const Duration(days: 29));
  return logs.where((l) {
    final parts = (l['log_date'] as String).split('-');
    final d = DateTime(
        int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    return !d.isBefore(cutoff);
  }).toList();
});

// ─── 7-day completion grid ────────────────────────────────────────────────────
// bool? → true = done, false = scheduled but not done, null = not scheduled

final sevenDayGridProvider =
    FutureProvider<Map<String, List<bool?>>>((ref) async {
  final logs = await ref.watch(allLogsProvider.future);
  final habits = await ref.watch(habitsProvider.future);
  final today = DateTime.now();
  return {
    for (final h in habits)
      h.id: List.generate(7, (i) {
        final date = today.subtract(Duration(days: 6 - i));
        if (!h.daysOfWeek.contains(date.weekday)) return null;
        final ds = _fmt(date);
        return logs.any((l) =>
            l['habit_id'] == h.id &&
            l['log_date'] == ds &&
            l['completed'] == true);
      }),
  };
});

// ─── Per-habit completion rate – denominator = scheduled days in last 30 ──────

final habitRates30Provider =
    FutureProvider<Map<String, double>>((ref) async {
  final logs = await ref.watch(recentLogsProvider.future);
  final habits = await ref.watch(habitsProvider.future);
  final today = DateTime.now();
  final Map<String, double> rates = {};

  for (final h in habits) {
    // Count only days this habit was actually scheduled in the last 30 days
    int scheduledDays = 0;
    for (int i = 1; i <= 30; i++) {
      final date = today.subtract(Duration(days: i));
      if (h.daysOfWeek.contains(date.weekday)) scheduledDays++;
    }

    if (scheduledDays == 0) {
      rates[h.id] = 0;
      continue;
    }

    final done = logs
        .where((l) => l['habit_id'] == h.id && l['completed'] == true)
        .length;
    rates[h.id] = done / scheduledDays;
  }
  return rates;
});

// ─── Top & bottom habits (last 30 days) ──────────────────────────────────────

typedef HabitRate = ({Habit habit, double rate});

final topHabitsProvider = FutureProvider<List<HabitRate>>((ref) async {
  final rates = await ref.watch(habitRates30Provider.future);
  final habits = await ref.watch(habitsProvider.future);
  final list = habits
      .map((h) => (habit: h, rate: rates[h.id] ?? 0.0))
      .toList()
    ..sort((a, b) => b.rate.compareTo(a.rate));
  return list.take(5).toList();
});

final bottomHabitsProvider = FutureProvider<List<HabitRate>>((ref) async {
  final rates = await ref.watch(habitRates30Provider.future);
  final habits = await ref.watch(habitsProvider.future);
  final list = habits
      .map((h) => (habit: h, rate: rates[h.id] ?? 0.0))
      .toList()
    ..sort((a, b) => a.rate.compareTo(b.rate));
  return list.take(5).toList();
});

// ─── Per-category stats (last 30 days) ───────────────────────────────────────

typedef CategoryStat = ({String category, double rate, int count});

final categoryStatsProvider =
    FutureProvider<List<CategoryStat>>((ref) async {
  final rates = await ref.watch(habitRates30Provider.future);
  final habits = await ref.watch(habitsProvider.future);
  final Map<String, List<double>> byCategory = {};
  for (final h in habits) {
    byCategory.putIfAbsent(h.category, () => []);
    byCategory[h.category]!.add(rates[h.id] ?? 0);
  }
  return byCategory.entries.map((e) {
    final avg = e.value.reduce((a, b) => a + b) / e.value.length;
    return (category: e.key, rate: avg, count: e.value.length);
  }).toList()
    ..sort((a, b) => b.rate.compareTo(a.rate));
});

// ─── Day-of-week completion pattern – naturally correct (uses actual logs) ────
// Index 0 = Monday … 6 = Sunday

final weekdayPatternProvider =
    FutureProvider<List<double>>((ref) async {
  final logs = await ref.watch(allLogsProvider.future);
  final completedByDay = List.filled(7, 0);
  final totalByDay = List.filled(7, 0);
  for (final l in logs) {
    final parts = (l['log_date'] as String).split('-');
    final date = DateTime(
        int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    final idx = date.weekday - 1;
    totalByDay[idx]++;
    if (l['completed'] == true) completedByDay[idx]++;
  }
  return List.generate(
      7, (i) => totalByDay[i] == 0 ? 0.0 : completedByDay[i] / totalByDay[i]);
});

// ─── Perfect days – only habits scheduled for that day must be done ───────────

final perfectDaysProvider = FutureProvider<int>((ref) async {
  final logs = await ref.watch(recentLogsProvider.future);
  final habits = await ref.watch(habitsProvider.future);
  if (habits.isEmpty) return 0;
  final today = DateTime.now();
  int perfect = 0;
  for (int i = 1; i <= 30; i++) {
    final date = today.subtract(Duration(days: i));
    final ds = _fmt(date);
    final scheduled =
        habits.where((h) => h.daysOfWeek.contains(date.weekday)).toList();
    if (scheduled.isEmpty) continue;
    final allDone = scheduled.every((h) => logs.any((l) =>
        l['habit_id'] == h.id &&
        l['log_date'] == ds &&
        l['completed'] == true));
    if (allDone) perfect++;
  }
  return perfect;
});

// ─── 30-day overall avg – denominator = scheduled habits per day ──────────────

final avg30Provider = FutureProvider<double>((ref) async {
  final logs = await ref.watch(recentLogsProvider.future);
  final habits = await ref.watch(habitsProvider.future);
  if (habits.isEmpty) return 0;
  final today = DateTime.now();
  double total = 0;
  int days = 0;
  for (int i = 1; i <= 30; i++) {
    final date = today.subtract(Duration(days: i));
    final ds = _fmt(date);
    final dayLogs = logs.where((l) => l['log_date'] == ds).toList();
    if (dayLogs.isEmpty) continue;
    final scheduled =
        habits.where((h) => h.daysOfWeek.contains(date.weekday)).toList();
    if (scheduled.isEmpty) continue;
    final scheduledIds = scheduled.map((h) => h.id).toSet();
    final done = dayLogs
        .where((l) =>
            l['completed'] == true && scheduledIds.contains(l['habit_id']))
        .length;
    total += done / scheduled.length;
    days++;
  }
  return days == 0 ? 0 : total / days;
});

// ─── Best active streak – non-scheduled days are transparent (don't break) ───

final bestStreakProvider = FutureProvider<(String, int)?>((ref) async {
  final logs = await ref.watch(allLogsProvider.future);
  final habits = await ref.watch(habitsProvider.future);
  if (habits.isEmpty) return null;
  final today = DateTime.now();
  String? bestName;
  int best = 0;

  for (final h in habits) {
    int streak = 0;
    for (int i = 0; i < 364; i++) {
      final date = today.subtract(Duration(days: i));
      // Skip days the habit is not scheduled — they don't break the streak
      if (!h.daysOfWeek.contains(date.weekday)) continue;
      if (logs.any((l) =>
          l['habit_id'] == h.id &&
          l['log_date'] == _fmt(date) &&
          l['completed'] == true)) {
        streak++;
      } else {
        break; // scheduled day not done → streak ends
      }
    }
    if (streak > best) {
      best = streak;
      bestName = h.name;
    }
  }
  return best == 0 ? null : (bestName!, best);
});
