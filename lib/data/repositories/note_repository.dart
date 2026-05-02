import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/daily_note.dart';

class NoteRepository {
  final SupabaseClient _client;
  NoteRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<DailyNote?> getNoteForDate(DateTime date) async {
    final data = await _client
        .from('daily_notes')
        .select()
        .eq('user_id', _userId)
        .eq('note_date', _fmt(date))
        .maybeSingle();
    return data == null ? null : DailyNote.fromJson(data);
  }

  Future<void> upsertNote(DateTime date, String text) async {
    await _client.from('daily_notes').upsert(
      {
        'user_id': _userId,
        'note_date': _fmt(date),
        'note_text': text,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id,note_date',
    );
  }

  Future<List<DailyNote>> getRecentNotes(int days) async {
    final from = DateTime.now().subtract(Duration(days: days));
    final data = await _client
        .from('daily_notes')
        .select()
        .eq('user_id', _userId)
        .gte('note_date', _fmt(from))
        .order('note_date', ascending: false);
    return (data as List)
        .map((e) => DailyNote.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
