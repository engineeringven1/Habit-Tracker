import 'package:supabase_flutter/supabase_flutter.dart';

class StatsRepository {
  final SupabaseClient _client;

  StatsRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;

  Future<List<Map<String, dynamic>>> getLast8Weeks() async {
    final data = await _client
        .from('weekly_stats')
        .select()
        .eq('user_id', _userId)
        .order('week_start', ascending: false)
        .limit(8);
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<Map<String, dynamic>?> getCurrentWeekStats() async {
    final weekStart = _currentWeekStart();
    final weekStartStr =
        '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';

    final data = await _client
        .from('weekly_stats')
        .select()
        .eq('user_id', _userId)
        .eq('week_start', weekStartStr)
        .maybeSingle();
    return data;
  }

  // Returns the Monday of the current week (ISO week: Monday = day 1)
  DateTime _currentWeekStart() {
    final now = DateTime.now();
    final daysFromMonday = now.weekday - 1;
    return DateTime(now.year, now.month, now.day - daysFromMonday);
  }
}
