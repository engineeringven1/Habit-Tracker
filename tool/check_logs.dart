import 'dart:convert';
import 'dart:io';

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
final url     = _env['OLD_SUPABASE_URL']       ?? (throw StateError('OLD_SUPABASE_URL not set in .env'));
final anonKey = _env['OLD_SUPABASE_SERVICE_KEY'] ?? (throw StateError('OLD_SUPABASE_SERVICE_KEY not set in .env'));

Future<dynamic> req(String method, String path,
    {dynamic body, String? token}) async {
  final uri = Uri.parse('$url$path');
  final client = HttpClient();
  final request = await client.openUrl(method, uri);
  request.headers.set('apikey', anonKey);
  request.headers.set('Content-Type', 'application/json');
  if (token != null) request.headers.set('Authorization', 'Bearer $token');
  if (body != null) {
    final encoded = utf8.encode(jsonEncode(body));
    request.contentLength = encoded.length;
    request.add(encoded);
  }
  final response = await request.close();
  final responseBody = await response.transform(utf8.decoder).join();
  client.close();
  if (responseBody.isEmpty) return null;
  return jsonDecode(responseBody);
}

String fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Future<void> main() async {
  final email    = _env['MIGRATE_EMAIL']    ?? (throw StateError('MIGRATE_EMAIL not set in .env'));
  final password = _env['MIGRATE_PASSWORD'] ?? (throw StateError('MIGRATE_PASSWORD not set in .env'));
  final auth = await req('POST', '/auth/v1/token?grant_type=password',
      body: {'email': email, 'password': password});
  final token = auth['access_token'] as String;
  final userId = auth['user']['id'] as String;
  print('=== User: $userId ===\n');

  // ── Check daily_logs last 7 days ──────────────────────────────────────────
  final today = DateTime.now();
  final start7 = fmt(today.subtract(const Duration(days: 6)));
  final end = fmt(today);

  final logs7 = await req('GET',
      '/rest/v1/daily_logs?select=habit_id,log_date,completed'
          '&user_id=eq.$userId&log_date=gte.$start7&log_date=lte.$end',
      token: token) as List;

  print('daily_logs last 7 days: ${logs7.length} rows');
  print('  completed=true : ${logs7.where((l) => l['completed'] == true).length}');
  if (logs7.isNotEmpty) {
    final sample = logs7.first;
    print('  sample row  : $sample');
    print('  log_date type: ${sample['log_date'].runtimeType}');
    print('  completed type: ${sample['completed'].runtimeType}');
  }

  // ── Check weekly_stats ────────────────────────────────────────────────────
  print('');
  final ws = await req('GET',
      '/rest/v1/weekly_stats?select=*&user_id=eq.$userId&order=week_start.desc&limit=5',
      token: token);

  if (ws is List) {
    print('weekly_stats rows: ${ws.length}');
    if (ws.isNotEmpty) {
      print('  latest: ${ws.first}');
    } else {
      print('  NO ROWS — weekly_stats is empty for this user.');
      print('  This means the bar chart will also show nothing.');
    }
  } else {
    print('weekly_stats response: $ws');
  }

  // ── Check habits ──────────────────────────────────────────────────────────
  print('');
  final habits = await req('GET',
      '/rest/v1/habits?select=id,name,sort_order&user_id=eq.$userId&is_active=eq.true&order=sort_order',
      token: token) as List;
  print('habits: ${habits.length} active');

  // ── Cross-check: do log habit_ids match habit ids? ────────────────────────
  if (logs7.isNotEmpty && habits.isNotEmpty) {
    final habitIds = habits.map((h) => h['id'] as String).toSet();
    final logHabitIds =
        logs7.map((l) => l['habit_id'] as String).toSet();
    final overlap = habitIds.intersection(logHabitIds);
    print('\nHabit ID overlap: ${overlap.length} / ${habitIds.length}');
    if (overlap.isEmpty) {
      print('  !! NO OVERLAP — log habit_ids do NOT match current habit ids!');
    }
  }
}
