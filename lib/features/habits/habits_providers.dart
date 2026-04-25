import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/notification_service.dart';
import '../../data/models/habit.dart';
import '../../data/models/reminder.dart';
import '../../data/repositories/habit_repository.dart';
import '../../data/repositories/reminder_repository.dart';
import '../tracker/tracker_providers.dart';

// ─── Habits StateNotifier ─────────────────────────────────────────────────────

class HabitsNotifier extends StateNotifier<AsyncValue<List<Habit>>> {
  final HabitRepository _repo;

  HabitsNotifier(this._repo) : super(const AsyncLoading()) {
    loadHabits();
  }

  Future<void> loadHabits() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final habits = await _repo.getHabits();
      habits.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return habits;
    });
  }

  Future<void> createHabit(Habit h) async {
    await _repo.createHabit(h);
    await loadHabits();
    if (h.notifyEnabled) {
      final habits = state.value;
      if (habits != null) {
        final created = habits.firstWhere(
          (x) => x.name == h.name && x.userId == h.userId,
          orElse: () => h,
        );
        await NotificationService.scheduleHabit(created);
      }
    }
  }

  Future<void> toggleActive(String id, bool value) async {
    final habits = state.value;
    if (habits == null) return;
    // Optimistic update
    state = AsyncData(
      habits.map((h) => h.id == id ? h.copyWith(isActive: value) : h).toList(),
    );
    await _repo.toggleActive(id, value);
  }

  Future<void> updateHabitFields({
    required String   id,
    required String   name,
    required String   category,
    required List<int> daysOfWeek,
    required bool     notifyEnabled,
    required int      notifyStartHr,
    required int      notifyEndHr,
  }) async {
    final habits = state.value;
    if (habits == null) return;
    final original = habits.firstWhere((h) => h.id == id);
    final updated = original.copyWith(
      name: name, category: category, daysOfWeek: daysOfWeek,
      notifyEnabled: notifyEnabled,
      notifyStartHr: notifyStartHr,
      notifyEndHr:   notifyEndHr,
    );
    state = AsyncData(
      habits.map((h) => h.id == id ? updated : h).toList(),
    );
    await _repo.updateHabit(updated);
    await NotificationService.scheduleHabit(updated);
  }

  Future<void> reorderHabits(int oldIndex, int newIndex) async {
    final habits = state.value;
    if (habits == null) return;

    final updated = List<Habit>.from(habits);
    final moved = updated.removeAt(oldIndex);
    updated.insert(newIndex, moved);

    // Assign new sort_order values
    for (int i = 0; i < updated.length; i++) {
      updated[i] = updated[i].copyWith(sortOrder: i);
    }
    // Optimistic update
    state = AsyncData(updated);

    // Persist only the range that changed
    final start = oldIndex < newIndex ? oldIndex : newIndex;
    final end = oldIndex > newIndex ? oldIndex : newIndex;
    for (int i = start; i <= end; i++) {
      await _repo.reorder(updated[i].id, updated[i].sortOrder);
    }
  }
}

final habitsNotifierProvider =
    StateNotifierProvider<HabitsNotifier, AsyncValue<List<Habit>>>(
  (ref) => HabitsNotifier(ref.read(habitRepositoryProvider)),
);

// ─── Reminders StateNotifier ──────────────────────────────────────────────────

class RemindersNotifier extends StateNotifier<AsyncValue<List<Reminder>>> {
  final ReminderRepository _repo;

  RemindersNotifier(this._repo) : super(const AsyncLoading()) {
    loadReminders();
  }

  Future<void> loadReminders() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repo.getReminders);
  }

  Future<void> createReminder(
    String name, {
    bool notifyEnabled = false,
    int notifyHr = 9,
  }) async {
    await _repo.createReminder(name, notifyEnabled: notifyEnabled, notifyHr: notifyHr);
    await loadReminders();
    if (notifyEnabled) {
      final reminders = state.value;
      if (reminders != null) {
        final created = reminders.firstWhere(
          (r) => r.name == name,
          orElse: () => Reminder(
            id: '', userId: '', name: name, isActive: true,
            notifyEnabled: notifyEnabled, notifyHr: notifyHr,
          ),
        );
        await NotificationService.scheduleReminder(created);
      }
    }
  }

  Future<void> toggleReminder(String id, bool value) async {
    final reminders = state.value;
    if (reminders == null) return;
    state = AsyncData(
      reminders
          .map((r) => r.id == id ? r.copyWith(isActive: value) : r)
          .toList(),
    );
    await _repo.toggleReminder(id, value);
  }

  Future<void> updateReminder(Reminder r) async {
    final reminders = state.value;
    if (reminders == null) return;
    state = AsyncData(
      reminders.map((x) => x.id == r.id ? r : x).toList(),
    );
    await _repo.updateReminder(r);
    await NotificationService.scheduleReminder(r);
  }

  Future<void> deleteReminder(String id) async {
    final reminders = state.value;
    if (reminders == null) return;
    await NotificationService.cancel(NotificationService.reminderId(id));
    state = AsyncData(reminders.where((r) => r.id != id).toList());
    await _repo.deleteReminder(id);
  }
}

final remindersNotifierProvider =
    StateNotifierProvider<RemindersNotifier, AsyncValue<List<Reminder>>>(
  (ref) => RemindersNotifier(ref.read(reminderRepositoryProvider)),
);

// ─── Categories Notifier ──────────────────────────────────────────────────────

class CategoriesNotifier extends StateNotifier<List<String>> {
  static const _key = 'app_categories';
  static const _defaults = [
    'disciplina', 'trabajo', 'salud', 'nutrición',
    'finanzas', 'mente', 'restricción',
  ];

  CategoriesNotifier() : super(_defaults) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_key);
    if (saved != null && saved.isNotEmpty) state = saved;
  }

  Future<void> add(String cat) async {
    final trimmed = cat.trim().toLowerCase();
    if (trimmed.isEmpty || state.contains(trimmed)) return;
    state = [...state, trimmed];
    await _persist();
  }

  Future<void> remove(String cat) async {
    if (state.length <= 1) return;
    state = state.where((c) => c != cat).toList();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, state);
  }
}

final categoriesProvider =
    StateNotifierProvider<CategoriesNotifier, List<String>>(
  (_) => CategoriesNotifier(),
);
