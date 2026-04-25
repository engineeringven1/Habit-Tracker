import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../data/models/habit.dart';
import '../../data/models/reminder.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // Notifications only work on Android/iOS, not on Windows/macOS/Linux desktop.
  static bool get _supported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  static const _channelId   = 'habit_reminders';
  static const _channelName = 'Recordatorios';
  static const _channelDesc = 'Notificaciones diarias de hábitos y recordatorios';

  // ── Init ──────────────────────────────────────────────────────────────────

  static Future<void> init() async {
    if (!_supported || _initialized) return;

    tz.initializeTimeZones();
    final localTzName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTzName));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: androidSettings));

    _initialized = true;
  }

  static Future<void> requestPermission() async {
    if (!_supported) return;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  // ── Schedule helpers ──────────────────────────────────────────────────────

  // Schedules a one-shot notification for today at [hour].
  // If that time has already passed today, nothing is scheduled.
  static Future<void> _scheduleOnce({
    required int id,
    required String title,
    required String body,
    required int hour,
  }) async {
    if (!_initialized || !_supported) return;
    final now = tz.TZDateTime.now(tz.local);
    final target = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
    if (!target.isAfter(now)) return; // window already passed

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      target,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      // No matchDateTimeComponents → fires once, not recurring
    );
  }

  static Future<void> cancel(int id) async {
    if (!_supported) return;
    await _plugin.cancel(id);
  }

  // ── Habit notifications ───────────────────────────────────────────────────

  static int habitId(String habitId) => habitId.hashCode.abs() % 50000;

  static Future<void> scheduleHabit(Habit h) async {
    if (!h.notifyEnabled) {
      await cancel(habitId(h.id));
      return;
    }
    await _scheduleOnce(
      id: habitId(h.id),
      title: h.name,
      body: '¡No olvides completar tu hábito!',
      hour: h.notifyEndHr,
    );
  }

  // ── Reminder notifications ────────────────────────────────────────────────

  static int reminderId(String reminderId) =>
      reminderId.hashCode.abs() % 50000 + 50000;

  static Future<void> scheduleReminder(Reminder r) async {
    if (!r.notifyEnabled) {
      await cancel(reminderId(r.id));
      return;
    }
    await _scheduleOnce(
      id: reminderId(r.id),
      title: r.name,
      body: '¡No olvides tu recordatorio!',
      hour: r.notifyHr,
    );
  }

  // ── Bulk reschedule on app start ──────────────────────────────────────────
  // [completedHabitIds]: habits already done today — skip their notifications.

  static Future<void> rescheduleAll(
    List<Habit> habits,
    List<Reminder> reminders, {
    Set<String> completedHabitIds = const {},
  }) async {
    if (!_supported) return;
    await _plugin.cancelAll();
    for (final h in habits) {
      if (h.notifyEnabled && !completedHabitIds.contains(h.id)) {
        await scheduleHabit(h);
      }
    }
    for (final r in reminders) {
      if (r.notifyEnabled) await scheduleReminder(r);
    }
  }
}
