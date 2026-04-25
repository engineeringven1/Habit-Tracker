// Migration script: Kaizen Structures → App Habit Traker
// Uses service-role keys to bypass auth entirely — no sign-in needed.
// Run with: dart tool/migrate_data.dart

import 'dart:convert';
import 'dart:io';
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

final _env = _loadEnv();

final _oldUrl = _env['OLD_SUPABASE_URL']      ?? (throw StateError('OLD_SUPABASE_URL not set in .env'));
final _oldKey = _env['OLD_SUPABASE_SERVICE_KEY'] ?? (throw StateError('OLD_SUPABASE_SERVICE_KEY not set in .env'));

final _newUrl = _env['SUPABASE_URL']      ?? (throw StateError('SUPABASE_URL not set in .env'));
final _newKey = _env['SUPABASE_ANON_KEY'] ?? (throw StateError('SUPABASE_ANON_KEY not set in .env'));

// Email of the user to migrate
final _email    = _env['MIGRATE_EMAIL']    ?? (throw StateError('MIGRATE_EMAIL not set in .env'));
final _password = _env['MIGRATE_PASSWORD'] ?? (throw StateError('MIGRATE_PASSWORD not set in .env'));

// ─── Admin helpers (service role bypasses RLS) ────────────────────────────────

Map<String, String> _headers(String key) => {
      'apikey': key,
      'Authorization': 'Bearer $key',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

Future<String> _getUserId(String baseUrl, String key, String email) async {
  final r = await http.get(
    Uri.parse('$baseUrl/auth/v1/admin/users?per_page=1000'),
    headers: _headers(key),
  );
  if (r.statusCode != 200) throw Exception('List users failed: ${r.body}');
  final body = jsonDecode(r.body);
  // Response can be {"users": [...]} or directly [...]
  final List users = body is Map ? (body['users'] as List? ?? []) : body as List;
  final match = users.cast<Map>().where((u) => u['email'] == email).toList();
  if (match.isEmpty) return '';
  return match.first['id'] as String;
}

Future<String> _createUser(String baseUrl, String key) async {
  final r = await http.post(
    Uri.parse('$baseUrl/auth/v1/admin/users'),
    headers: _headers(key),
    body: jsonEncode({'email': _email, 'password': _password, 'email_confirm': true}),
  );
  if (r.statusCode != 200 && r.statusCode != 201) {
    throw Exception('Create user failed: ${r.body}');
  }
  return (jsonDecode(r.body) as Map)['id'] as String;
}

Future<List<Map<String, dynamic>>> _select(
  String baseUrl,
  String key,
  String table,
  String filter,
) async {
  final r = await http.get(
    Uri.parse('$baseUrl/rest/v1/$table?$filter'),
    headers: _headers(key),
  );
  if (r.statusCode != 200) throw Exception('SELECT $table failed: ${r.body}');
  return List<Map<String, dynamic>>.from(jsonDecode(r.body) as List);
}

Future<Map<String, dynamic>> _insertOne(
  String baseUrl,
  String key,
  String table,
  Map<String, dynamic> row,
) async {
  final r = await http.post(
    Uri.parse('$baseUrl/rest/v1/$table'),
    headers: {..._headers(key), 'Prefer': 'return=representation'},
    body: jsonEncode(row),
  );
  if (r.statusCode != 200 && r.statusCode != 201) {
    throw Exception('INSERT $table failed: ${r.body}');
  }
  final result = jsonDecode(r.body);
  return (result is List ? result.first : result) as Map<String, dynamic>;
}

Future<void> _insertBatch(
  String baseUrl,
  String key,
  String table,
  List<Map<String, dynamic>> rows,
) async {
  if (rows.isEmpty) return;
  for (var i = 0; i < rows.length; i += 500) {
    final chunk = rows.sublist(i, (i + 500).clamp(0, rows.length));
    final r = await http.post(
      Uri.parse('$baseUrl/rest/v1/$table'),
      headers: {..._headers(key), 'Prefer': 'return=minimal'},
      body: jsonEncode(chunk),
    );
    if (r.statusCode != 200 && r.statusCode != 201) {
      throw Exception('INSERT $table chunk failed: ${r.body}');
    }
    print('  → ${chunk.length} rows inserted (offset $i)');
  }
}

// ─── Main ─────────────────────────────────────────────────────────────────────

Future<void> main() async {
  print('=== Habit Tracker Migration ===\n');

  // 1. Get old user ID
  print('[1/6] Finding user in old project...');
  final oldUserId = await _getUserId(_oldUrl, _oldKey, _email);
  if (oldUserId.isEmpty) throw Exception('User $_email not found in old project');
  print('  Old user_id: $oldUserId');

  // 2. Get or create user in new project
  print('\n[2/6] Finding user in new project...');
  String newUserId = await _getUserId(_newUrl, _newKey, _email);
  if (newUserId.isEmpty) {
    print('  Not found — creating...');
    newUserId = await _createUser(_newUrl, _newKey);
    print('  Created with id: $newUserId');
  } else {
    print('  Found existing user_id: $newUserId');
  }

  // 3. Clean up any existing data in new project (makes script safe to re-run)
  print('\n[3/6] Cleaning existing data in new project...');
  for (final table in ['mentor_insights', 'daily_logs', 'reminders', 'habits']) {
    final r = await http.delete(
      Uri.parse('$_newUrl/rest/v1/$table?user_id=eq.$newUserId'),
      headers: _headers(_newKey),
    );
    if (r.statusCode != 200 && r.statusCode != 204) {
      print('  Warning: could not clean $table: ${r.body}');
    } else {
      print('  Cleaned $table');
    }
  }

  // 4. Read habits from old project
  print('\n[4/6] Reading habits...');
  final oldHabits = await _select(
    _oldUrl, _oldKey, 'habits',
    'user_id=eq.$oldUserId&order=sort_order.asc&limit=200',
  );
  print('  Found ${oldHabits.length} habits');

  // 4. Insert habits & build ID map
  print('\n[4/6] Inserting habits...');
  final habitIdMap = <String, String>{};
  for (final h in oldHabits) {
    final created = await _insertOne(_newUrl, _newKey, 'habits', {
      'user_id':    newUserId,
      'name':       h['name'],
      'category':   h['category'],
      'has_score':  h['has_score'],
      'is_active':  h['is_active'],
      'sort_order': h['sort_order'],
      'created_at': h['created_at'],
    });
    habitIdMap[h['id'] as String] = created['id'] as String;
    stdout.write('.');
  }
  print('\n  Inserted ${habitIdMap.length} habits');

  // 5. Read and migrate daily_logs
  print('\n[5/6] Reading daily logs...');
  final oldLogs = await _select(
    _oldUrl, _oldKey, 'daily_logs',
    'user_id=eq.$oldUserId&order=log_date.asc&limit=5000',
  );
  print('  Found ${oldLogs.length} logs');

  final newLogs = oldLogs
      .where((l) => habitIdMap.containsKey(l['habit_id'] as String))
      .map((l) => {
            'user_id':   newUserId,
            'habit_id':  habitIdMap[l['habit_id'] as String],
            'log_date':  l['log_date'],
            'completed': l['completed'],
          })
      .toList();
  await _insertBatch(_newUrl, _newKey, 'daily_logs', newLogs);

  // 6. Read and migrate reminders
  print('\n[6/6] Reading reminders...');
  final oldReminders = await _select(
    _oldUrl, _oldKey, 'reminders',
    'user_id=eq.$oldUserId&limit=100',
  );
  print('  Found ${oldReminders.length} reminders');

  final newReminders = oldReminders
      .map((r) => {
            'user_id':   newUserId,
            'name':      r['name'],
            'is_active': r['is_active'],
          })
      .toList();
  await _insertBatch(_newUrl, _newKey, 'reminders', newReminders);

  print('\n✓ Migration complete!');
  print('  Habits:     ${habitIdMap.length}');
  print('  Daily logs: ${newLogs.length}');
  print('  Reminders:  ${newReminders.length}');
  print('\nHot restart the app and log in with the same credentials.');
  exit(0);
}
