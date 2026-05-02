import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class InsightService {
  InsightService._();
  static final InsightService instance = InsightService._();

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String get _yesterday =>
      _fmtDate(DateTime.now().subtract(const Duration(days: 1)));

  Future<String> getInsight(
    String statId,
    Map<String, dynamic> data,
    String apiKey,
  ) async {
    final yesterday = _yesterday;
    final prefs = await SharedPreferences.getInstance();

    final cached = prefs.getString('insight_$statId');
    if (cached != null) {
      try {
        final map = jsonDecode(cached) as Map<String, dynamic>;
        if (map['date'] == yesterday) return (map['text'] as String?) ?? '';
      } catch (_) {}
    }

    final prompt = _buildPrompt(statId, data);
    if (prompt.isEmpty) return '';

    try {
      const systemMsg = 'Eres un analista de hábitos. Responde en español. '
          'Máximo 200 caracteres. Sin saludos. Directo y accionable.';

      final response = await http
          .post(
            Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': 'llama-3.1-8b-instant',
              'max_tokens': 80,
              'temperature': 0.7,
              'messages': [
                {'role': 'system', 'content': systemMsg},
                {'role': 'user', 'content': prompt},
              ],
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return '';

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final text =
          (decoded['choices'][0]['message']['content'] as String).trim();

      await prefs.setString(
        'insight_$statId',
        jsonEncode({'text': text, 'date': yesterday}),
      );
      return text;
    } catch (_) {
      return '';
    }
  }

  String _buildPrompt(String statId, Map<String, dynamic> data) {
    switch (statId) {
      case 'weekly_progress':
        final yPct = data['yesterday_pct'] as int? ?? 0;
        final avg7 = data['avg7'] as int? ?? 0;
        return 'Ayer completé el $yPct%. Mi promedio 7 días es $avg7%. '
            'Dame una observación accionable en máximo 200 caracteres.';

      case 'weekly_pattern':
        final days =
            (data['days'] as List?)?.cast<int>() ?? List.filled(7, 0);
        return 'Mi % por día: L${days[0]} M${days[1]} X${days[2]} '
            'J${days[3]} V${days[4]} S${days[5]} D${days[6]}. '
            '¿Qué patrón ves y qué debería hacer? Máximo 200 caracteres.';

      case 'category_performance':
        final cats =
            (data['categories'] as Map?)?.cast<String, int>() ?? {};
        if (cats.isEmpty) return '';
        final list =
            cats.entries.map((e) => '${e.key} ${e.value}%').join(', ');
        return 'Mis categorías últimos 7 días: $list. '
            '¿Cuál es mi mayor brecha y cómo atacarla? Máximo 200 caracteres.';

      case 'radar_insight':
        final cats =
            (data['categories'] as Map?)?.cast<String, int>() ?? {};
        if (cats.isEmpty) return '';
        final list =
            cats.entries.map((e) => '${e.key} ${e.value}%').join(', ');
        return 'Mi radar de hábitos 30 días: $list. '
            'Identifica el desequilibrio más crítico. Máximo 200 caracteres.';

      case 'failure_distribution':
        final days =
            (data['days'] as List?)?.cast<int>() ?? List.filled(7, 0);
        return 'Mis fallos por día: L${days[0]}% M${days[1]}% X${days[2]}% '
            'J${days[3]}% V${days[4]}% S${days[5]}% D${days[6]}%. '
            '¿Por qué creo que fallo ese día y qué hacer? Máximo 200 caracteres.';

      case 'week_comparison':
        final deltas =
            (data['deltas'] as Map?)?.cast<String, int>() ?? {};
        if (deltas.isEmpty) return '';
        final list = deltas.entries
            .map((e) => '${e.key} ${e.value >= 0 ? '+' : ''}${e.value}pp')
            .join(', ');
        return 'Mis deltas por categoría vs semana anterior: $list. '
            '¿Qué tendencia es más importante? Máximo 200 caracteres.';

      case 'attention_insight':
        final habits =
            (data['habits'] as List?)?.cast<Map>() ?? [];
        if (habits.isEmpty) return '';
        final list =
            habits.map((h) => '${h['name']} ${h['pct']}%').join(', ');
        return 'Mis 3 hábitos más débiles: $list. '
            'Dame una estrategia concreta. Máximo 200 caracteres.';

      case 'arena_insight':
        final level = data['level'] as String? ?? '';
        final pts = data['pts'] as int? ?? 0;
        final ptsToNext = data['ptsToNext'] as int? ?? 0;
        final nextLevel = data['nextLevel'] as String? ?? '';
        final streak = data['streak'] as int? ?? 0;
        return 'Soy nivel $level, tengo $pts puntos, me faltan $ptsToNext '
            'para $nextLevel, racha activa más larga: $streak días. '
            '¿Qué debería priorizar hoy? Máximo 200 caracteres.';

      default:
        return '';
    }
  }
}
