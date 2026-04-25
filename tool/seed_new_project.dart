// Seed 52 weeks of habit history for the new project.
// Run with: dart tool/seed_new_project.dart

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;

// ─── .env loader (dart:io, no flutter_dotenv) ─────────────────────────────────

Map<String, String> _loadEnv([String path = '.env']) {
  final file = File(path);
  if (!file.existsSync()) return {};
  final result = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final idx = trimmed.indexOf('=');
    if (idx < 0) continue;
    result[trimmed.substring(0, idx).trim()] = trimmed.substring(idx + 1).trim();
  }
  return result;
}

// ─── Config ───────────────────────────────────────────────────────────────────

final _env    = _loadEnv();
final _url    = _env['SUPABASE_URL']      ?? (throw StateError('SUPABASE_URL not set in .env'));
final _key    = _env['SUPABASE_ANON_KEY'] ?? (throw StateError('SUPABASE_ANON_KEY not set in .env'));
final _userId = _env['SUPABASE_USER_ID']  ?? (throw StateError('SUPABASE_USER_ID not set in .env'));

Map<String, String> get _headers => {
  'apikey': _key,
  'Authorization': 'Bearer $_key',
  'Content-Type': 'application/json',
  'Accept': 'application/json',
};

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Future<void> main() async {
  final rng = Random(42);

  // 1. Fetch habits
  print('Fetching habits...');
  final r = await http.get(
    Uri.parse('$_url/rest/v1/habits?user_id=eq.$_userId&is_active=eq.true&order=sort_order.asc&limit=100'),
    headers: _headers,
  );
  if (r.statusCode != 200) throw Exception('Failed to fetch habits: ${r.body}');
  final habits = List<Map<String, dynamic>>.from(jsonDecode(r.body) as List);
  print('Found ${habits.length} habits');
  if (habits.isEmpty) {
    print('No habits found — make sure the migration ran first.');
    return;
  }

  // 2. Delete existing daily_logs
  print('Clearing existing logs...');
  final del = await http.delete(
    Uri.parse('$_url/rest/v1/daily_logs?user_id=eq.$_userId'),
    headers: _headers,
  );
  if (del.statusCode != 200 && del.statusCode != 204) {
    print('Warning: ${del.body}');
  }
  print('Logs cleared.');

  // 3. Build completion rate per habit based on category
  final categoryBase = <String, double>{
    'restricción': 0.88,
    'salud':       0.72,
    'disciplina':  0.68,
    'mente':       0.65,
    'nutrición':   0.62,
    'finanzas':    0.63,
    'trabajo':     0.75,
  };

  // 4. Generate 52 weeks of logs
  print('Generating 52 weeks of logs...');
  final today = DateTime.now();
  final rows = <Map<String, dynamic>>[];

  for (int weekIdx = 0; weekIdx < 52; weekIdx++) {
    // Progress factor: starts lower, improves over 52 weeks
    final progress = weekIdx / 51.0; // 0.0 → 1.0
    final weekBoost = 0.45 + progress * 0.40; // 45% → 85%

    for (int dayIdx = 0; dayIdx < 7; dayIdx++) {
      final daysAgo = (51 - weekIdx) * 7 + (6 - dayIdx);
      final date = today.subtract(Duration(days: daysAgo));
      final ds = _fmt(date);
      final isWeekend = date.weekday >= 6;
      final dayMult = isWeekend ? 0.80 : 1.0;

      for (final habit in habits) {
        final cat = (habit['category'] as String).toLowerCase();
        final base = categoryBase[cat] ?? 0.65;
        final prob = (base * weekBoost * dayMult).clamp(0.0, 0.97);
        final completed = rng.nextDouble() < prob;

        rows.add({
          'user_id':   _userId,
          'habit_id':  habit['id'],
          'log_date':  ds,
          'completed': completed,
        });
      }
    }
  }

  print('Total rows to insert: ${rows.length}');

  // 5. Insert in batches of 500
  for (var i = 0; i < rows.length; i += 500) {
    final chunk = rows.sublist(i, (i + 500).clamp(0, rows.length));
    final res = await http.post(
      Uri.parse('$_url/rest/v1/daily_logs'),
      headers: {..._headers, 'Prefer': 'return=minimal'},
      body: jsonEncode(chunk),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Insert failed at offset $i: ${res.body}');
    }
    final pct = ((i + chunk.length) / rows.length * 100).round();
    print('  $pct% — inserted ${i + chunk.length}/${rows.length} rows');
  }

  print('\n✓ Done! ${rows.length} log entries created for ${habits.length} habits across 52 weeks.');
}
