import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/notification_service.dart';
import '../../data/models/daily_log.dart';
import '../../data/models/habit.dart';
import '../../data/models/reminder.dart';
import '../../data/repositories/habit_repository.dart';
import '../../data/repositories/log_repository.dart';
import '../../data/repositories/reminder_repository.dart';
import '../widget/widget_service.dart';

// ─── Repository Providers ────────────────────────────────────────────────────

final habitRepositoryProvider = Provider<HabitRepository>(
  (ref) => HabitRepository(Supabase.instance.client),
);

final logRepositoryProvider = Provider<LogRepository>(
  (ref) => LogRepository(Supabase.instance.client),
);

final reminderRepositoryProvider = Provider<ReminderRepository>(
  (ref) => ReminderRepository(Supabase.instance.client),
);

// ─── Selected Date ────────────────────────────────────────────────────────────

final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

// ─── Data Providers ──────────────────────────────────────────────────────────

final habitsProvider = FutureProvider<List<Habit>>(
  (ref) => ref.read(habitRepositoryProvider).getHabits(),
);

final remindersProvider = FutureProvider<List<Reminder>>(
  (ref) => ref.read(reminderRepositoryProvider).getReminders(),
);

// ─── Daily Logs StateNotifier ────────────────────────────────────────────────

class DailyLogsNotifier
    extends StateNotifier<AsyncValue<List<DailyLog>>> {
  final LogRepository _repo;
  final Ref _ref;
  final DateTime date;

  DailyLogsNotifier(this._repo, this._ref, {required this.date})
      : super(const AsyncLoading()) {
    loadLogs();
  }

  Future<void> loadLogs() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.getLogsForDate(date));
  }

  Future<void> toggle(String habitId, bool completed) async {
    final current = state.value ?? [];

    // Optimistic update — UI responds immediately
    final exists = current.any((l) => l.habitId == habitId);
    if (exists) {
      state = AsyncData(current
          .map((l) =>
              l.habitId == habitId ? l.copyWith(completed: completed) : l)
          .toList());
    } else if (completed) {
      final now = DateTime.now();
      state = AsyncData([
        ...current,
        DailyLog(
          id: '',
          userId: '',
          habitId: habitId,
          logDate: date,
          completed: true,
          createdAt: now,
          updatedAt: now,
        ),
      ]);
    } else {
      state = AsyncData(current.where((l) => l.habitId != habitId).toList());
    }

    // Persist to database — must happen before notification logic.
    try {
      await _repo.upsertLog(habitId, date, completed);
      final fresh = await _repo.getLogsForDate(date);
      state = AsyncData(fresh);
    } catch (_) {
      await loadLogs();
      return;
    }

    // Widget update — non-critical, fire and forget.
    unawaited(_updateWidget());

    // Notifications are secondary — errors here must not undo the saved log.
    final now = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    if (isToday) {
      try {
        final habits = _ref.read(habitsProvider).value ?? [];
        final habit = habits
            .cast<Habit?>()
            .firstWhere((h) => h?.id == habitId, orElse: () => null);
        if (habit != null && habit.notifyEnabled) {
          if (completed) {
            await NotificationService.cancel(
                NotificationService.habitId(habitId));
          } else {
            await NotificationService.scheduleHabit(habit);
          }
        }
      } catch (_) {
        // Notification errors are non-critical.
      }
    }
  }

  Future<void> updateLog(
    String habitId, {
    required bool completed,
    required bool manuallyFailed,
    DateTime? completedAt,
  }) async {
    final current = state.value ?? [];
    final exists = current.any((l) => l.habitId == habitId);
    if (exists) {
      state = AsyncData(current
          .map((l) => l.habitId == habitId
              ? l.copyWith(
                  completed: completed,
                  manuallyFailed: manuallyFailed,
                  completedAt: completed ? completedAt : null,
                  clearCompletedAt: !completed,
                )
              : l)
          .toList());
    } else if (completed || manuallyFailed) {
      final now = DateTime.now();
      state = AsyncData([
        ...current,
        DailyLog(
          id: '',
          userId: '',
          habitId: habitId,
          logDate: date,
          completed: completed,
          manuallyFailed: manuallyFailed,
          completedAt: completed ? completedAt : null,
          createdAt: now,
          updatedAt: now,
        ),
      ]);
    }
    try {
      await _repo.upsertLog(
        habitId, date, completed,
        manuallyFailed: manuallyFailed,
        completedAt: completedAt,
      );
      final fresh = await _repo.getLogsForDate(date);
      state = AsyncData(fresh);
    } catch (_) {
      await loadLogs();
    }

    unawaited(_updateWidget());
  }

  Future<void> markFailed(String habitId, bool failed) async {
    final current = state.value ?? [];

    // Optimistic update
    final exists = current.any((l) => l.habitId == habitId);
    if (exists) {
      state = AsyncData(current
          .map((l) => l.habitId == habitId
              ? l.copyWith(
                  completed: false,
                  manuallyFailed: failed,
                  clearCompletedAt: true,
                )
              : l)
          .toList());
    } else if (failed) {
      final now = DateTime.now();
      state = AsyncData([
        ...current,
        DailyLog(
          id: '',
          userId: '',
          habitId: habitId,
          logDate: date,
          completed: false,
          manuallyFailed: true,
          createdAt: now,
          updatedAt: now,
        ),
      ]);
    }

    try {
      await _repo.upsertLog(habitId, date, false, manuallyFailed: failed);
      final fresh = await _repo.getLogsForDate(date);
      state = AsyncData(fresh);
    } catch (_) {
      await loadLogs();
    }

    unawaited(_updateWidget());
  }

  Future<void> _updateWidget() async {
    try {
      final habits = _ref.read(habitsProvider).value ?? [];
      if (habits.isEmpty) return;

      final logs = state.value ?? [];
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final weekday = today.weekday;

      int completed = 0;
      final total = habits.length;
      for (final h in habits) {
        if (!h.daysOfWeek.contains(weekday)) {
          completed++;
        } else if (logs.any((l) => l.habitId == h.id && l.completed)) {
          completed++;
        }
      }

      final pending = habits.where((h) {
        if (!h.daysOfWeek.contains(weekday)) return false;
        return !logs.any((l) => l.habitId == h.id && l.completed);
      }).toList();

      if (pending.isEmpty) {
        await WidgetService.update(
          completed: completed,
          total: total,
          worstPendingHabitNames: [],
        );
        return;
      }

      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

      final cutoff = today.subtract(const Duration(days: 30));
      final rawLogs = await client
          .from('daily_logs')
          .select('habit_id, completed')
          .eq('user_id', userId)
          .gte('log_date', cutoff.toIso8601String().substring(0, 10))
          .lt('log_date', today.toIso8601String().substring(0, 10));

      final completionCount = <String, int>{};
      for (final log in rawLogs as List) {
        final hId = log['habit_id'] as String;
        if (log['completed'] == true) {
          completionCount[hId] = (completionCount[hId] ?? 0) + 1;
        }
      }

      pending.sort((a, b) =>
          (completionCount[a.id] ?? 0).compareTo(completionCount[b.id] ?? 0));

      await WidgetService.update(
        completed: completed,
        total: total,
        worstPendingHabitNames: pending.take(3).map((h) => h.name).toList(),
      );
    } catch (_) {
      // Widget update is non-critical.
    }
  }
}

final dailyLogsProvider = StateNotifierProvider<
    DailyLogsNotifier, AsyncValue<List<DailyLog>>>(
  (ref) {
    final date = ref.watch(selectedDateProvider);
    return DailyLogsNotifier(
      ref.read(logRepositoryProvider),
      ref,
      date: date,
    );
  },
);

// ─── Reminder done state (in-memory, resets each session) ────────────────────
// Stores {reminderId: dateString} — auto-clears when the date changes.

class ReminderDoneNotifier extends StateNotifier<Map<String, String>> {
  ReminderDoneNotifier() : super({});

  String get _today {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  void toggle(String id) {
    final today = _today;
    final next = Map<String, String>.from(state);
    if (next[id] == today) {
      next.remove(id);
    } else {
      next[id] = today;
      // Cancel the notification — user just marked it done.
      NotificationService.cancel(NotificationService.reminderId(id));
    }
    state = next;
  }

  bool isDone(String id) => state[id] == _today;
}

final reminderDoneProvider =
    StateNotifierProvider<ReminderDoneNotifier, Map<String, String>>(
  (_) => ReminderDoneNotifier(),
);

// ─── Derived Score ────────────────────────────────────────────────────────────
// Returns (completedCount, totalCount).
// Habits not scheduled today are counted as auto-completed.

final dailyScoreProvider = Provider<(int, int)>((ref) {
  final logsAsync = ref.watch(dailyLogsProvider);
  final habitsAsync = ref.watch(habitsProvider);
  final selectedDate = ref.watch(selectedDateProvider);

  return logsAsync.when(
    data: (logs) => habitsAsync.when(
      data: (habits) {
        final weekday = selectedDate.weekday;
        final total = habits.length;
        int completed = 0;
        for (final h in habits) {
          if (!h.daysOfWeek.contains(weekday)) {
            completed++; // not scheduled that day → auto-completed
          } else if (logs.any((l) => l.habitId == h.id && l.completed)) {
            completed++;
          }
        }
        return (completed, total);
      },
      loading: () => (0, 0),
      error: (_, _) => (0, 0),
    ),
    loading: () => (0, 0),
    error: (_, _) => (0, 0),
  );
});
