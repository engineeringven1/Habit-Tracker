import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/reminder.dart';

class ReminderRepository {
  final SupabaseClient _client;

  ReminderRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;

  Future<List<Reminder>> getReminders() async {
    final data = await _client
        .from('reminders')
        .select()
        .eq('user_id', _userId)
        .order('name');
    return (data as List).map((e) => Reminder.fromJson(e)).toList();
  }

  Future<void> createReminder(
    String name, {
    bool notifyEnabled = false,
    int notifyHr = 9,
  }) async {
    await _client.from('reminders').insert({
      'user_id':        _userId,
      'name':           name,
      'is_active':      true,
      'notify_enabled': notifyEnabled,
      'notify_hr':      notifyHr,
    });
  }

  Future<void> updateReminder(Reminder r) async {
    await _client.from('reminders').update({
      'name':           r.name,
      'is_active':      r.isActive,
      'notify_enabled': r.notifyEnabled,
      'notify_hr':      r.notifyHr,
    }).eq('id', r.id).eq('user_id', _userId);
  }

  Future<void> toggleReminder(String id, bool value) async {
    await _client
        .from('reminders')
        .update({'is_active': value})
        .eq('id', id)
        .eq('user_id', _userId);
  }

  Future<void> deleteReminder(String id) async {
    await _client
        .from('reminders')
        .delete()
        .eq('id', id)
        .eq('user_id', _userId);
  }
}
