import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/daily_log.dart';

class LogRepository {
  final SupabaseClient _client;

  LogRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;

  String _dateStr(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<List<DailyLog>> getLogsForDate(DateTime date) async {
    final data = await _client
        .from('daily_logs')
        .select()
        .eq('user_id', _userId)
        .eq('log_date', _dateStr(date));
    return (data as List).map((e) => DailyLog.fromJson(e)).toList();
  }

  Future<void> upsertLog(
    String habitId,
    DateTime date,
    bool completed, {
    bool manuallyFailed = false,
    DateTime? completedAt, // null → uses DateTime.now() for completed
  }) async {
    final dateStr = _dateStr(date);

    final existing = await _client
        .from('daily_logs')
        .select('id')
        .eq('user_id', _userId)
        .eq('habit_id', habitId)
        .eq('log_date', dateStr)
        .maybeSingle();

    final completedAtStr = completed
        ? (completedAt ?? DateTime.now()).toUtc().toIso8601String()
        : null;

    if (existing != null) {
      await _client
          .from('daily_logs')
          .update({
            'completed':       completed,
            'manually_failed': manuallyFailed,
            'completed_at':    completedAtStr,
          })
          .eq('id', existing['id'] as String)
          .eq('user_id', _userId);
    } else {
      await _client.from('daily_logs').insert({
        'user_id':         _userId,
        'habit_id':        habitId,
        'log_date':        dateStr,
        'completed':       completed,
        'manually_failed': manuallyFailed,
        'completed_at':    completedAtStr,
      });
    }
  }

  Future<int> getScoreForDate(DateTime date) async {
    // Join with habits to filter only scored habits
    final data = await _client
        .from('daily_logs')
        .select('id, habits!inner(has_score)')
        .eq('user_id', _userId)
        .eq('log_date', _dateStr(date))
        .eq('completed', true)
        .eq('habits.has_score', true);
    return (data as List).length;
  }
}
