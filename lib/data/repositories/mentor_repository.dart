import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/mentor_insight.dart';

class MentorRepository {
  final SupabaseClient _client;

  MentorRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;

  Future<List<MentorInsight>> getInsights() async {
    final data = await _client
        .from('mentor_insights')
        .select()
        .eq('user_id', _userId);
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(MentorInsight.fromMap)
        .toList();
  }

  Future<void> upsertInsight(String blockType, String content) async {
    await _client.from('mentor_insights').upsert(
      {
        'user_id': _userId,
        'block_type': blockType,
        'content': content,
        'generated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id,block_type',
    );
  }
}
