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
    bool weekHasActivity = false;
    final startOffset = weekIdx * 7;

    for (int dayOff = 0; dayOff < 7; dayOff++) {
      final date = today.subtract(Duration(days: startOffset + dayOff));
      final ds = _fmt(date);
      final weekday = date.weekday;

      if (logs.any((l) => l['log_date'] == ds)) weekHasActivity = true;

      final scheduledIds = habits
          .where((h) => h.daysOfWeek.contains(weekday))
          .map((h) => h.id)
          .toSet();

      total += habits.length;
      completed += habits.length - scheduledIds.length;
      completed += logs
          .where((l) =>
              l['log_date'] == ds &&
              scheduledIds.contains(l['habit_id']) &&
              l['completed'] == true)
          .length;
    }

    // Only show the bar for weeks where the user had at least one log.
    if (weekHasActivity) {
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
        .select('habit_id, log_date, completed, completed_at')
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
      // days 7..1 from today → excludes today, shows the last 7 completed days
      h.id: List.generate(7, (i) {
        final date = today.subtract(Duration(days: 7 - i));
        if (!h.daysOfWeek.contains(date.weekday)) return null;
        final ds = _fmt(date);
        return logs.any((l) =>
            l['habit_id'] == h.id &&
            l['log_date'] == ds &&
            l['completed'] == true);
      }),
  };
});

// ─── Per-habit completion rate ────────────────────────────────────────────────
// Denominator = scheduled days since first log (capped at 30).
// Numerator   = completions on days the habit was actually scheduled.

final habitRates30Provider =
    FutureProvider<Map<String, double>>((ref) async {
  final logs = await ref.watch(recentLogsProvider.future);
  final habits = await ref.watch(habitsProvider.future);
  final today = DateTime.now();
  final Map<String, double> rates = {};

  // Find how many calendar days the user has been using the app (max 30).
  DateTime? earliest;
  for (final l in logs) {
    final parts = (l['log_date'] as String).split('-');
    final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    if (earliest == null || d.isBefore(earliest)) earliest = d;
  }
  final lookback = earliest == null
      ? 30
      : today.difference(earliest).inDays.clamp(1, 30);

  // Build a fast lookup: habitId → set of scheduled dates it was completed.
  final completedDates = <String, Set<String>>{};
  for (final l in logs) {
    if (l['completed'] != true) continue;
    final id = l['habit_id'] as String;
    completedDates.putIfAbsent(id, () => {});
    completedDates[id]!.add(l['log_date'] as String);
  }

  for (final h in habits) {
    int scheduledDays = 0;
    int done = 0;

    for (int i = 1; i <= lookback; i++) {
      final date = today.subtract(Duration(days: i));
      if (!h.daysOfWeek.contains(date.weekday)) continue;
      scheduledDays++;
      if (completedDates[h.id]?.contains(_fmt(date)) == true) done++;
    }

    rates[h.id] = scheduledDays == 0 ? 0 : (done / scheduledDays).clamp(0.0, 1.0);
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

// ─── Day-of-week completion pattern ──────────────────────────────────────────
// Index 0 = Monday … 6 = Sunday
// Averages the daily completion rate across all occurrences of each weekday
// where the user had any activity (same "all habits" logic as the hero card).

final weekdayPatternProvider =
    FutureProvider<List<double>>((ref) async {
  final logs = await ref.watch(allLogsProvider.future);
  final habits = await ref.watch(habitsProvider.future);
  if (habits.isEmpty) return List.filled(7, 0.0);

  final today = DateTime.now();
  final rateSum = List.filled(7, 0.0);
  final dayCount = List.filled(7, 0);

  for (int i = 0; i < 364; i++) {
    final date = today.subtract(Duration(days: i));
    final ds = _fmt(date);
    if (!logs.any((l) => l['log_date'] == ds)) continue;

    final idx = date.weekday - 1;
    dayCount[idx]++;

    final scheduledIds = habits
        .where((h) => h.daysOfWeek.contains(date.weekday))
        .map((h) => h.id)
        .toSet();

    final autoCompleted = habits.length - scheduledIds.length;
    final done = logs
        .where((l) =>
            l['log_date'] == ds &&
            scheduledIds.contains(l['habit_id']) &&
            l['completed'] == true)
        .length;

    rateSum[idx] += (autoCompleted + done) / habits.length;
  }

  return List.generate(
      7, (i) => dayCount[i] == 0 ? 0.0 : rateSum[i] / dayCount[i]);
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
      if (!h.daysOfWeek.contains(date.weekday)) continue;
      final done = logs.any((l) =>
          l['habit_id'] == h.id &&
          l['log_date'] == _fmt(date) &&
          l['completed'] == true);
      if (done) {
        streak++;
      } else if (i == 0) {
        // Today scheduled but not yet marked — don't break the streak, just skip
        continue;
      } else {
        break;
      }
    }
    if (streak > best) {
      best = streak;
      bestName = h.name;
    }
  }
  return best == 0 ? null : (bestName!, best);
});

// ─── Hero card – always counts last 7 days (no activity filter) ──────────────

typedef WeekStats = ({int completed, int total, double pct});

final heroWeekProvider =
    FutureProvider<({WeekStats current, WeekStats? prev})>((ref) async {
  final logs = await ref.watch(allLogsProvider.future);
  final habits = await ref.watch(habitsProvider.future);
  if (habits.isEmpty) {
    return (
      current: (completed: 0, total: 0, pct: 0.0),
      prev: null,
    );
  }

  final today = DateTime.now();

  WeekStats calcWeek(int startOffset) {
    int completed = 0;
    int total = 0;
    for (int dayOff = 0; dayOff < 7; dayOff++) {
      final date = today.subtract(Duration(days: startOffset + dayOff));
      final ds = _fmt(date);
      final scheduledIds = habits
          .where((h) => h.daysOfWeek.contains(date.weekday))
          .map((h) => h.id)
          .toSet();
      total += habits.length;
      completed += habits.length - scheduledIds.length;
      completed += logs
          .where((l) =>
              l['log_date'] == ds &&
              scheduledIds.contains(l['habit_id']) &&
              l['completed'] == true)
          .length;
    }
    final pct = total == 0 ? 0.0 : (completed / total * 100).roundToDouble();
    return (completed: completed, total: total, pct: pct);
  }

  return (current: calcWeek(0), prev: calcWeek(7));
});

// ─── Top 5 habits by active streak ───────────────────────────────────────────

typedef HabitStreak = ({Habit habit, int streak});

final top5StreaksProvider = FutureProvider<List<HabitStreak>>((ref) async {
  final logs = await ref.watch(allLogsProvider.future);
  final habits = await ref.watch(habitsProvider.future);
  if (habits.isEmpty) return [];
  final today = DateTime.now();

  final result = <HabitStreak>[];
  for (final h in habits) {
    int streak = 0;
    for (int i = 0; i < 364; i++) {
      final date = today.subtract(Duration(days: i));
      if (!h.daysOfWeek.contains(date.weekday)) continue;
      final done = logs.any((l) =>
          l['habit_id'] == h.id &&
          l['log_date'] == _fmt(date) &&
          l['completed'] == true);
      if (done) {
        streak++;
      } else if (i == 0) {
        continue;
      } else {
        break;
      }
    }
    if (streak > 0) result.add((habit: h, streak: streak));
  }

  result.sort((a, b) => b.streak.compareTo(a.streak));
  return result.take(5).toList();
});

// ─── Completion time distribution ────────────────────────────────────────────
// Groups completed logs by time-of-day bucket using the completed_at timestamp.

typedef TimeBucket = ({String label, String timeRange, int count, double pct});

final completionTimeProvider = FutureProvider<List<TimeBucket>>((ref) async {
  final logs = await ref.watch(allLogsProvider.future);

  final counts = List.filled(5, 0);
  int total = 0;

  for (final log in logs) {
    if (log['completed'] != true) continue;
    final raw = log['completed_at'];
    if (raw == null) continue;

    final h = DateTime.parse(raw as String).toLocal().hour;
    final idx = h >= 5 && h < 9
        ? 0
        : h >= 9 && h < 12
            ? 1
            : h >= 12 && h < 17
                ? 2
                : h >= 17 && h < 21
                    ? 3
                    : 4;
    counts[idx]++;
    total++;
  }

  final labels = ['Madrugada', 'Mañana', 'Tarde', 'Atardecer', 'Noche'];
  final ranges = ['5–9 am', '9–12 pm', '12–5 pm', '5–9 pm', '9 pm+'];

  return List.generate(5, (i) => (
    label: labels[i],
    timeRange: ranges[i],
    count: counts[i],
    pct: total == 0 ? 0.0 : counts[i] / total,
  ));
});

// ─── Per-habit streak: current + all-time record ─────────────────────────────

typedef HabitStreakData = ({int current, int record});

final habitStreakProvider =
    FutureProvider.family<HabitStreakData, String>((ref, habitId) async {
  final logs = await ref.watch(allLogsProvider.future);
  final habits = await ref.watch(habitsProvider.future);
  final today = DateTime.now();

  final habit = habits.cast<Habit?>()
      .firstWhere((h) => h?.id == habitId, orElse: () => null);
  if (habit == null) return (current: 0, record: 0);

  // Current streak: backwards from today; non-scheduled days are transparent.
  int current = 0;
  for (int i = 0; i < 364; i++) {
    final date = today.subtract(Duration(days: i));
    if (!habit.daysOfWeek.contains(date.weekday)) continue;
    final done = logs.any((l) =>
        l['habit_id'] == habitId &&
        l['log_date'] == _fmt(date) &&
        l['completed'] == true);
    if (done) {
      current++;
    } else if (i == 0) {
      continue; // today not yet marked — don't break the streak
    } else {
      break;
    }
  }

  // All-time record: longest uninterrupted run over the full 364-day window.
  int record = current; // current is already a valid candidate
  int running = 0;
  for (int i = 363; i >= 0; i--) {
    final date = today.subtract(Duration(days: i));
    if (!habit.daysOfWeek.contains(date.weekday)) continue;
    final done = logs.any((l) =>
        l['habit_id'] == habitId &&
        l['log_date'] == _fmt(date) &&
        l['completed'] == true);
    if (done) {
      running++;
      if (running > record) record = running;
    } else if (i == 0) {
      continue; // today not done yet — don't break historical run
    } else {
      running = 0;
    }
  }

  return (current: current, record: record);
});

// ─── Category week-over-week trend ───────────────────────────────────────────
// Returns 4-week history per category: [oldest, ..., current].
// "Current" = Mon of this week → today. "Prev" = last full Mon–Sun week.

typedef CategoryTrend = ({
  double? current,
  double? prev,
  List<double?> fourWeeks,
});

final categoryWeekTrendProvider =
    FutureProvider<Map<String, CategoryTrend>>((ref) async {
  final logs = await ref.watch(allLogsProvider.future);
  final habits = await ref.watch(habitsProvider.future);
  if (habits.isEmpty) return {};

  final today = DateTime.now();
  final todayNorm = DateTime(today.year, today.month, today.day);
  final currentMonday =
      todayNorm.subtract(Duration(days: todayNorm.weekday - 1));

  // weeks[0] = oldest, weeks[3] = current (ends today)
  final weekStarts = List.generate(
      4, (i) => currentMonday.subtract(Duration(days: 7 * (3 - i))));
  final weekEnds = List.generate(4, (i) => i == 3
      ? todayNorm
      : weekStarts[i].add(const Duration(days: 6)));

  // Pre-build completed set for O(1) lookup
  final completedByDate = <String, Set<String>>{};
  for (final l in logs) {
    if (l['completed'] == true) {
      final ds = l['log_date'] as String;
      completedByDate.putIfAbsent(ds, () => {}).add(l['habit_id'] as String);
    }
  }

  final categories = habits.map((h) => h.category).toSet();
  final result = <String, CategoryTrend>{};

  for (final cat in categories) {
    final catHabits = habits.where((h) => h.category == cat).toList();
    final fourWeeks = <double?>[];

    for (int w = 0; w < 4; w++) {
      int total = 0;
      int completed = 0;
      var d = weekStarts[w];
      while (!d.isAfter(weekEnds[w])) {
        final ds = _fmt(d);
        for (final h in catHabits) {
          if (!h.daysOfWeek.contains(d.weekday)) continue;
          total++;
          if (completedByDate[ds]?.contains(h.id) == true) completed++;
        }
        d = d.add(const Duration(days: 1));
      }
      fourWeeks.add(total == 0 ? null : completed / total);
    }

    result[cat] = (
      current: fourWeeks[3],
      prev: fourWeeks[2],
      fourWeeks: fourWeeks,
    );
  }

  return result;
});

// ─── Failure distribution by weekday ─────────────────────────────────────────
// For each day Mon–Sun: failure % = (scheduled – completed) / scheduled.
// Requires ≥ 14 days of data; only past days (not today) are counted.

typedef WeekdayFailureItem = ({String name, double rate});
typedef WeekdayFailInfo = ({
  int weekday,
  double failureRate,
  int fails,
  int total,
  List<WeekdayFailureItem> worst,
});
typedef FailureWeekdayData = ({bool hasEnoughData, List<WeekdayFailInfo> days});

final failureByWeekdayProvider = FutureProvider<FailureWeekdayData>((ref) async {
  final logs = await ref.watch(recentLogsProvider.future);
  final habits = await ref.watch(habitsProvider.future);

  WeekdayFailInfo emptyDay(int wd) => (
    weekday: wd,
    failureRate: 0.0,
    fails: 0,
    total: 0,
    worst: <WeekdayFailureItem>[],
  );

  if (habits.isEmpty) {
    return (
      hasEnoughData: false,
      days: List.generate(7, (i) => emptyDay(i + 1)),
    );
  }

  final today = DateTime.now();
  final todayNorm = DateTime(today.year, today.month, today.day);

  // Check ≥ 14 days of history
  DateTime? earliest;
  for (final l in logs) {
    final parts = (l['log_date'] as String).split('-');
    final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    if (earliest == null || d.isBefore(earliest)) earliest = d;
  }
  final hasEnoughData =
      earliest != null && todayNorm.difference(earliest).inDays >= 13;

  // O(1) completed lookup
  final completedSet = <String>{};
  for (final l in logs) {
    if (l['completed'] == true) {
      completedSet.add('${l['habit_id']}_${l['log_date']}');
    }
  }

  // Past dates per weekday (exclude today, last 30 days)
  final datesByWd = List.generate(7, (_) => <String>[]);
  for (int i = 1; i <= 30; i++) {
    final date = today.subtract(Duration(days: i));
    datesByWd[date.weekday - 1].add(_fmt(date));
  }

  final days = <WeekdayFailInfo>[];
  for (int wd = 1; wd <= 7; wd++) {
    final dates = datesByWd[wd - 1];
    final scheduled = habits.where((h) => h.daysOfWeek.contains(wd)).toList();

    if (scheduled.isEmpty || dates.isEmpty) {
      days.add(emptyDay(wd));
      continue;
    }

    int totalOpp = 0;
    int totalFails = 0;
    final habitRates = <WeekdayFailureItem>[];

    for (final h in scheduled) {
      final done = dates.where((ds) => completedSet.contains('${h.id}_$ds')).length;
      final opp = dates.length;
      final fails = opp - done;
      totalOpp += opp;
      totalFails += fails;
      if (fails > 0) habitRates.add((name: h.name, rate: fails / opp));
    }

    habitRates.sort((a, b) => b.rate.compareTo(a.rate));

    days.add((
      weekday: wd,
      failureRate: totalOpp == 0 ? 0.0 : totalFails / totalOpp,
      fails: totalFails,
      total: totalOpp,
      worst: habitRates.take(3).toList(),
    ));
  }

  return (hasEnoughData: hasEnoughData, days: days);
});
