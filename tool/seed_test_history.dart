// Run with:  dart run tool/seed_test_history.dart
// Inserts 12 weeks of daily_log history + populates weekly_stats for the test user.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

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

final _env      = _loadEnv();
final _url      = _env['OLD_SUPABASE_URL']       ?? (throw StateError('OLD_SUPABASE_URL not set in .env'));
final _anonKey  = _env['OLD_SUPABASE_SERVICE_KEY'] ?? (throw StateError('OLD_SUPABASE_SERVICE_KEY not set in .env'));
final _email    = _env['MIGRATE_EMAIL']    ?? (throw StateError('MIGRATE_EMAIL not set in .env'));
final _password = _env['MIGRATE_PASSWORD'] ?? (throw StateError('MIGRATE_PASSWORD not set in .env'));

const _rates = {
  'disciplina': 0.78,
  'trabajo': 0.88,
  'finanzas': 0.72,
  'salud': 0.65,
  'mente': 0.70,
  'nutrición': 0.62,
  'restricción': 0.55,
};

final _rand = Random(2024);

Future<void> main() async {
  // ── 1. Sign in ──────────────────────────────────────────────────────────────
  stdout.write('Signing in as $_email ... ');
  final authData = await _req('POST', '/auth/v1/token?grant_type=password',
      body: {'email': _email, 'password': _password});
  final token = authData['access_token'] as String;
  final userId = authData['user']['id'] as String;
  print('OK');

  // ── 2. Get or seed habits ───────────────────────────────────────────────────
  var habits = await _getHabits(userId, token);
  if (habits.isEmpty) {
    print('No habits — seeding...');
    await _seedHabits(userId, token);
    habits = await _getHabits(userId, token);
  }
  print('Habits: ${habits.length}');

  // ── 3. Clear old data ───────────────────────────────────────────────────────
  stdout.write('Clearing old logs ... ');
  await _req('DELETE', '/rest/v1/daily_logs?user_id=eq.$userId', token: token);
  print('OK');

  // ── 4. Build 12 weeks of daily_logs ────────────────────────────────────────
  print('Inserting 12 weeks of daily_logs...');
  final today = DateTime.now();
  var totalRows = 0;

  for (int weekBack = 11; weekBack >= 0; weekBack--) {
    final progress = (11 - weekBack) / 11.0;
    final weekBonus = progress * 0.35;
    final batch = <Map<String, dynamic>>[];

    for (int d = 6; d >= 0; d--) {
      final date = today.subtract(Duration(days: weekBack * 7 + d));
      if (date.isAfter(today)) continue;
      final ds = _fmt(date);
      final isWeekend = date.weekday >= 6;
      final dayDelta = isWeekend ? -0.08 : 0.0;
      for (final h in habits) {
        final base = _rates[h['category'] as String] ?? 0.65;
        final rate = (base + weekBonus + dayDelta).clamp(0.0, 1.0);
        final completed = _rand.nextDouble() < rate;
        batch.add({
          'user_id': userId,
          'habit_id': h['id'],
          'log_date': ds,
          'completed': completed,
        });
      }
    }

    await _req(
      'POST',
      '/rest/v1/daily_logs?on_conflict=user_id,habit_id,log_date',
      body: batch,
      token: token,
      extra: {'Prefer': 'resolution=merge-duplicates'},
    );
    totalRows += batch.length;
    print('  Week ${12 - weekBack}/12  (${batch.length} rows)');
  }
  print('daily_logs: $totalRows rows inserted');
  print('\nweekly_stats is a DB view — it updates automatically.');
  print('Done!');
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Future<List<Map<String, dynamic>>> _getHabits(
    String userId, String token) async {
  final data = await _req('GET',
      '/rest/v1/habits?select=id,category,sort_order'
          '&user_id=eq.$userId&is_active=eq.true&order=sort_order',
      token: token);
  return (data as List).cast<Map<String, dynamic>>();
}

Future<void> _seedHabits(String userId, String token) async {
  final now = DateTime.now().toUtc().toIso8601String();
  await _req('POST', '/rest/v1/habits',
      body: [
        _h(userId, 0, 'Levantarse 5:30AM', 'disciplina', now),
        _h(userId, 1, 'TSM (proyecto)', 'trabajo', now),
        _h(userId, 2, 'PAXG (inversión)', 'finanzas', now),
        _h(userId, 3, 'Caminata 2 vueltas', 'salud', now),
        _h(userId, 4, 'Potencia (pesas)', 'salud', now),
        _h(userId, 5, 'Inglés podcast 30min', 'mente', now),
        _h(userId, 6, 'Limpieza facial', 'disciplina', now),
        _h(userId, 7, 'Lectura 30min', 'mente', now),
        _h(userId, 8, 'Meditación', 'mente', now),
        _h(userId, 9, 'Inglés comprensión 30min', 'mente', now),
        _h(userId, 10, 'Creatina', 'salud', now),
        _h(userId, 11, 'Arenero del gato', 'disciplina', now),
        _h(userId, 12, 'Minoxidil', 'disciplina', now),
        _h(userId, 13, 'Desayuno en casa', 'nutrición', now),
        _h(userId, 14, 'Almuerzo en casa', 'nutrición', now),
        _h(userId, 15, 'Cena en casa', 'nutrición', now),
        _h(userId, 16, 'No chuchería', 'restricción', now),
        _h(userId, 17, 'No comida basura', 'restricción', now),
        _h(userId, 18, 'No bebidas azucaradas', 'restricción', now),
        _h(userId, 19, 'No pornografía', 'restricción', now),
      ],
      token: token);
}

Map<String, dynamic> _h(String userId, int order, String name, String category,
        String createdAt) =>
    {
      'user_id': userId,
      'name': name,
      'category': category,
      'has_score': true,
      'is_active': true,
      'sort_order': order,
      'created_at': createdAt,
    };

Future<dynamic> _req(String method, String path,
    {dynamic body,
    String? token,
    Map<String, String> extra = const {}}) async {
  final uri = Uri.parse('$_url$path');
  final client = HttpClient();
  final request = await client.openUrl(method, uri);
  request.headers.set('apikey', _anonKey);
  request.headers.set('Content-Type', 'application/json');
  if (token != null) request.headers.set('Authorization', 'Bearer $token');
  for (final e in extra.entries) {
    request.headers.set(e.key, e.value);
  }
  if (body != null) {
    final encoded = utf8.encode(jsonEncode(body));
    request.contentLength = encoded.length;
    request.add(encoded);
  }
  final response = await request.close();
  final responseBody = await response.transform(utf8.decoder).join();
  client.close();
  if (response.statusCode >= 400) {
    throw Exception(
        'HTTP ${response.statusCode} on $method $path\n$responseBody');
  }
  if (responseBody.isEmpty) return null;
  return jsonDecode(responseBody);
}
