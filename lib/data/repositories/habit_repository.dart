import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/habit.dart';

class HabitRepository {
  final SupabaseClient _client;

  HabitRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;

  Future<List<Habit>> getHabits() async {
    final data = await _client
        .from('habits')
        .select()
        .eq('user_id', _userId)
        .eq('is_active', true)
        .order('sort_order', ascending: true);
    final list = (data as List).map((e) => Habit.fromJson(e)).toList();
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  Future<void> createHabit(Habit h) async {
    final data = h.toJson();
    if (h.id.isEmpty) data.remove('id'); // Let DB generate UUID
    await _client.from('habits').insert(data);
  }

  Future<void> updateHabit(Habit h) async {
    await _client
        .from('habits')
        .update(h.toJson())
        .eq('id', h.id)
        .eq('user_id', _userId);
  }

  Future<void> toggleActive(String id, bool value) async {
    await _client
        .from('habits')
        .update({'is_active': value})
        .eq('id', id)
        .eq('user_id', _userId);
  }

  Future<void> reorder(String id, int newOrder) async {
    await _client
        .from('habits')
        .update({'sort_order': newOrder})
        .eq('id', id)
        .eq('user_id', _userId);
  }

  Future<void> updateCelebratedMilestones(String id, List<int> milestones) async {
    await _client
        .from('habits')
        .update({'celebrated_milestones': milestones})
        .eq('id', id)
        .eq('user_id', _userId);
  }

  Future<bool> hasHabits() async {
    final data = await _client
        .from('habits')
        .select('id')
        .eq('user_id', _userId)
        .eq('is_active', true)
        .limit(1);
    return (data as List).isNotEmpty;
  }
}
