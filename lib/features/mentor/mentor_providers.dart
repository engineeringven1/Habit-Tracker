import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/mentor_insight.dart';
import '../../data/repositories/mentor_repository.dart';
import '../stats/stats_providers.dart';
import '../tracker/tracker_providers.dart';

// ─── Claude API Key ───────────────────────────────────────────────────────────

class AiKeyNotifier extends StateNotifier<String?> {
  static const _prefKey = 'ai_api_key';

  AiKeyNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_prefKey);
  }

  Future<void> save(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(_prefKey);
      state = null;
    } else {
      await prefs.setString(_prefKey, trimmed);
      state = trimmed;
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
    state = null;
  }
}

final aiKeyProvider =
    StateNotifierProvider<AiKeyNotifier, String?>((_) => AiKeyNotifier());

// ─── Repository ───────────────────────────────────────────────────────────────

final mentorRepositoryProvider = Provider<MentorRepository>(
  (ref) => MentorRepository(Supabase.instance.client),
);

// ─── Mentor Notifier ─────────────────────────────────────────────────────────

class MentorNotifier extends StateNotifier<Map<String, MentorInsight>> {
  final MentorRepository _repo;
  final Ref _ref;

  MentorNotifier(this._repo, this._ref) : super({}) {
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _repo.getInsights();
      state = {for (final i in list) i.blockType: i};
    } catch (_) {}
  }

  Future<String?> generateAll() async {
    final apiKey = _ref.read(aiKeyProvider);
    if (apiKey == null || apiKey.isEmpty) return 'API key no configurada';

    try {
      final data = await _buildDataSummary();
      final text = await _callGroq(apiKey, _promptAll(data), jsonMode: true);
      final jsonStr = _extractJson(text);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      for (final entry in json.entries) {
        if (entry.value is String && (entry.value as String).isNotEmpty) {
          await _repo.upsertInsight(entry.key, entry.value as String);
        }
      }
      await _load();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> generateBlock(String blockType) async {
    final apiKey = _ref.read(aiKeyProvider);
    if (apiKey == null || apiKey.isEmpty) return 'API key no configurada';

    try {
      final data = await _buildDataSummary();
      final text = await _callGroq(apiKey, _promptSingle(blockType, data));
      await _repo.upsertInsight(blockType, text.trim());
      await _load();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ─── Groq REST API (OpenAI-compatible, modelo LLaMA gratuito) ────────────

  Future<String> _callGroq(String apiKey, String prompt, {bool jsonMode = false}) async {
    final body = <String, dynamic>{
      'model': 'llama-3.1-8b-instant',
      'max_tokens': 2048,
      'temperature': 0.7,
      'messages': [
        {
          'role': 'system',
          'content': jsonMode
              ? 'Eres un coach de hábitos. Responde SIEMPRE con JSON válido y nada más. Sin markdown, sin explicaciones.'
              : 'Eres un coach de hábitos personal, empático y motivador. Responde en español.',
        },
        {'role': 'user', 'content': prompt},
      ],
    };
    if (jsonMode) body['response_format'] = {'type': 'json_object'};

    final response = await http.post(
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      final rb = jsonDecode(response.body) as Map<String, dynamic>;
      final message = (rb['error'] as Map?)?['message'] ?? 'HTTP ${response.statusCode}';
      throw Exception('Error de Groq: $message');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final text = data['choices'][0]['message']['content'] as String;
    return text;
  }

  // ─── Data compilation ─────────────────────────────────────────────────────

  Future<String> _buildDataSummary() async {
    final habits = await _ref.read(habitsProvider.future);
    final rates = await _ref.read(habitRates30Provider.future);
    final weekdayPattern = await _ref.read(weekdayPatternProvider.future);
    final categoryStats = await _ref.read(categoryStatsProvider.future);
    final avg30 = await _ref.read(avg30Provider.future);
    final perfectDays = await _ref.read(perfectDaysProvider.future);
    final bestStreak = await _ref.read(bestStreakProvider.future);
    final allLogs = await _ref.read(allLogsProvider.future);

    final today = DateTime.now();

    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    double weekAvg(int offsetDays) {
      double total = 0;
      int count = 0;
      for (int i = 0; i < 7; i++) {
        final ds = fmt(today.subtract(Duration(days: offsetDays + i)));
        final dayLogs = allLogs.where((l) => l['log_date'] == ds).toList();
        if (dayLogs.isEmpty || habits.isEmpty) continue;
        total += dayLogs.where((l) => l['completed'] == true).length / habits.length;
        count++;
      }
      return count == 0 ? 0 : total / count;
    }

    final week1 = weekAvg(0);
    final week2 = weekAvg(7);

    const dayNames = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
    int bestDayIdx = 0, worstDayIdx = 0;
    for (int i = 1; i < 7; i++) {
      if (weekdayPattern[i] > weekdayPattern[bestDayIdx]) bestDayIdx = i;
      if (weekdayPattern[i] < weekdayPattern[worstDayIdx]) worstDayIdx = i;
    }

    final sorted = habits
        .map((h) => (name: h.name, rate: rates[h.id] ?? 0.0))
        .toList()
      ..sort((a, b) => b.rate.compareTo(a.rate));
    final top3 =
        sorted.take(3).map((h) => '${h.name} (${(h.rate * 100).round()}%)').join(', ');
    final bottom3 = sorted.reversed
        .take(3)
        .map((h) => '${h.name} (${(h.rate * 100).round()}%)')
        .join(', ');

    final sb = StringBuffer();
    sb.writeln('Total hábitos activos: ${habits.length}');
    sb.writeln('Promedio de completado últimos 30 días: ${(avg30 * 100).round()}%');
    sb.writeln('Días perfectos (todos los hábitos completos) en últimos 30 días: $perfectDays/30');
    if (bestStreak != null) {
      sb.writeln('Mejor racha activa: "${bestStreak.$1}" — ${bestStreak.$2} días consecutivos');
    }
    sb.writeln('Última semana: ${(week1 * 100).round()}% vs semana anterior: ${(week2 * 100).round()}%');
    sb.writeln(
        'Mejor día de la semana: ${dayNames[bestDayIdx]} (${(weekdayPattern[bestDayIdx] * 100).round()}%)');
    sb.writeln(
        'Peor día de la semana: ${dayNames[worstDayIdx]} (${(weekdayPattern[worstDayIdx] * 100).round()}%)');
    sb.writeln('Rendimiento por categoría (últimos 30 días):');
    for (final c in categoryStats) {
      sb.writeln('  ${c.category}: ${(c.rate * 100).round()}%');
    }
    sb.writeln('Mejores hábitos: $top3');
    sb.writeln('Hábitos con mayor dificultad: $bottom3');
    return sb.toString();
  }

  // ─── Prompts ──────────────────────────────────────────────────────────────

  String _promptAll(String data) => '''
Eres un coach de hábitos personal, empático y motivador. Analiza los datos del usuario y genera exactamente 5 bloques de consejo en español. Responde SOLO con JSON válido, sin markdown ni texto adicional.

Formato:
{
  "weekly_pulse": "...",
  "monthly_trend": "...",
  "hidden_pattern": "...",
  "habit_at_risk": "...",
  "whats_working": "..."
}

Instrucciones por bloque:
- weekly_pulse: Comportamiento de los últimos 7 días vs semana anterior. Tono conversacional y específico.
- monthly_trend: Tendencia del mes por categorías. Identifica si hay mejora, estancamiento o retroceso.
- hidden_pattern: Patrón por días de la semana. Señala el mejor y peor día con posible explicación.
- habit_at_risk: El hábito con más dificultad. Da un consejo concreto y accionable para mejorarlo.
- whats_working: Celebra el éxito. Menciona la racha activa, el mejor hábito y los días perfectos.

Cada bloque: 80–120 palabras, párrafo fluido (sin listas ni viñetas), específico con los datos reales.

DATOS DEL USUARIO:
$data''';

  String _promptSingle(String blockType, String data) {
    const descriptions = {
      'weekly_pulse':
          'Analiza el comportamiento de los últimos 7 días vs semana anterior. Tono conversacional y específico.',
      'monthly_trend':
          'Habla de la tendencia del mes por categorías. Identifica mejora, estancamiento o retroceso.',
      'hidden_pattern':
          'Revela el patrón de días de la semana. Señala el mejor y peor día con posible explicación.',
      'habit_at_risk':
          'Identifica el hábito con más dificultad y da un consejo concreto y accionable.',
      'whats_working':
          'Celebra el éxito. Menciona la racha activa, el mejor hábito y los días perfectos.',
    };
    return '''
Eres un coach de hábitos personal, empático y motivador. Genera UN bloque de consejo en español para el apartado "$blockType".
${descriptions[blockType] ?? ''}
Responde SOLO con el texto del consejo (80–120 palabras, párrafo fluido, sin listas).

DATOS DEL USUARIO:
$data''';
  }

  String _extractJson(String text) {
    final cleaned = text.replaceAll(RegExp(r'```json\s*|\s*```'), '').trim();
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start == -1 || end == -1) throw FormatException('Respuesta JSON inválida');
    return cleaned.substring(start, end + 1);
  }
}

final mentorProvider =
    StateNotifierProvider<MentorNotifier, Map<String, MentorInsight>>(
  (ref) => MentorNotifier(ref.read(mentorRepositoryProvider), ref),
);
