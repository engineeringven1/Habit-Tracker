import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/habit.dart';
import '../../data/models/mentor_insight.dart';
import '../../data/repositories/mentor_repository.dart';
import '../arena/arena_providers.dart' show arenaChatCountProvider;
import '../stats/stats_providers.dart';
import '../tracker/note_providers.dart';
import '../tracker/tracker_providers.dart';

// ─── Prefill provider (1C) ────────────────────────────────────────────────────

final habitNamePrefillProvider = StateProvider<String?>((ref) => null);

// ─── AI Key ───────────────────────────────────────────────────────────────────

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

// ─── Top-level Groq REST helper ───────────────────────────────────────────────

Future<String> _groqChat(
  String apiKey,
  String systemMsg,
  List<Map<String, String>> messages, {
  bool jsonMode = false,
  int maxTokens = 2048,
}) async {
  final body = <String, dynamic>{
    'model': 'llama-3.1-8b-instant',
    'max_tokens': maxTokens,
    'temperature': 0.7,
    'messages': [
      {'role': 'system', 'content': systemMsg},
      ...messages,
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
    final message =
        (rb['error'] as Map?)?['message'] ?? 'HTTP ${response.statusCode}';
    throw Exception('Error de Groq: $message');
  }

  final data = jsonDecode(response.body) as Map<String, dynamic>;
  return data['choices'][0]['message']['content'] as String;
}

// ─── Repository ───────────────────────────────────────────────────────────────

final mentorRepositoryProvider = Provider<MentorRepository>(
  (ref) => MentorRepository(Supabase.instance.client),
);

// ─── Mentor Notifier (insights + weekly plan) ────────────────────────────────

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
      final data = await buildDataSummary();
      final text = await _groqChat(
        apiKey,
        'Eres un coach de hábitos. Responde SIEMPRE con JSON válido y nada más. Sin markdown, sin explicaciones.',
        [{'role': 'user', 'content': _promptAll(data)}],
        jsonMode: true,
      );
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
      final data = await buildDataSummary();
      final text = await _groqChat(
        apiKey,
        'Eres un coach de hábitos personal, empático y motivador. Responde en español.',
        [{'role': 'user', 'content': _promptSingle(blockType, data)}],
      );
      await _repo.upsertInsight(blockType, text.trim());
      await _load();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ─── 1B: Weekly plan ────────────────────────────────────────────────────────

  Future<String> generateWeeklyPlan() async {
    final apiKey = _ref.read(aiKeyProvider);
    if (apiKey == null || apiKey.isEmpty) throw Exception('API key no configurada');

    final habits = await _ref.read(habitsProvider.future);
    final allLogs = await _ref.read(allLogsProvider.future);
    final categoryStats = await _ref.read(categoryStatsProvider.future);
    final today = DateTime.now();

    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    // Completion count per habit in last 7 days
    final done7 = <String, int>{};
    for (final l in allLogs) {
      if (l['completed'] != true) continue;
      final ds = l['log_date'] as String;
      final dDate = DateTime.tryParse(ds);
      if (dDate == null) continue;
      if (today.difference(dDate).inDays < 7) {
        done7[l['habit_id'] as String] = (done7[l['habit_id'] as String] ?? 0) + 1;
      }
    }

    final habitRates7 = habits.map((h) {
      int scheduled = 0;
      for (int i = 0; i < 7; i++) {
        if (h.daysOfWeek.contains(today.subtract(Duration(days: i)).weekday)) {
          scheduled++;
        }
      }
      final rate = scheduled > 0 ? (done7[h.id] ?? 0) / scheduled : 0.0;
      return (name: h.name, rate: rate);
    }).toList()
      ..sort((a, b) => a.rate.compareTo(b.rate));

    // Also compute previous week rates for categories
    final catLines = StringBuffer();
    for (final c in categoryStats) {
      final catHabits = habits.where((h) => h.category == c.category);
      int prevDone = 0, prevSched = 0;
      for (final h in catHabits) {
        for (int i = 7; i < 14; i++) {
          final d = today.subtract(Duration(days: i));
          if (!h.daysOfWeek.contains(d.weekday)) continue;
          prevSched++;
          if (allLogs.any((l) =>
              l['habit_id'] == h.id &&
              l['log_date'] == fmt(d) &&
              l['completed'] == true)) {
            prevDone++;
          }
        }
      }
      final prevPct = prevSched > 0 ? (prevDone * 100 ~/ prevSched) : 0;
      catLines.writeln(
          '  ${c.category}: esta semana ${(c.rate * 100).round()}% / semana anterior $prevPct%');
    }

    final worstLines = habitRates7.take(3).map((h) =>
        '  ${h.name}: ${(h.rate * 100).round()}% últimos 7 días').join('\n');

    final prompt = '''Eres un coach de hábitos. Genera EXACTAMENTE 3 prioridades para esta semana.
Formato obligatorio (una por línea, sin numeración, sin guiones):
[Nombre del hábito]: [Acción concreta esta semana]

Rendimiento por categoría (esta semana / semana anterior):
$catLines
Los 3 hábitos con menor cumplimiento (últimos 7 días):
$worstLines

Responde SOLO con las 3 líneas en el formato indicado, sin texto adicional.''';

    return await _groqChat(
      apiKey,
      'Eres un coach de hábitos. Responde en español con exactamente 3 prioridades.',
      [{'role': 'user', 'content': prompt}],
      maxTokens: 300,
    );
  }

  Future<void> saveWeeklyPlan(String plan) async {
    await _repo.upsertInsight('weekly_plan', plan.trim());
    await _load();
  }

  // ─── Exposed for ChatNotifier ────────────────────────────────────────────────

  Future<String> buildDataSummary() => _buildDataSummary();

  // ─── Data summary ────────────────────────────────────────────────────────────

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

    const dayNames = [
      'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'
    ];
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
    sb.writeln(
        'Días perfectos (todos los hábitos completos) en últimos 30 días: $perfectDays/30');
    if (bestStreak != null) {
      sb.writeln(
          'Mejor racha activa: "${bestStreak.$1}" — ${bestStreak.$2} días consecutivos');
    }
    sb.writeln(
        'Última semana: ${(week1 * 100).round()}% vs semana anterior: ${(week2 * 100).round()}%');
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

    try {
      final notes = await _ref.read(recentNotesProvider(7).future);
      if (notes.isNotEmpty) {
        sb.writeln('\nNotas del usuario últimos 7 días:');
        for (final n in notes) {
          final d = n.noteDate;
          sb.writeln(
              '  ${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}: ${n.noteText}');
        }
      }
    } catch (_) {}

    return sb.toString();
  }

  // ─── Prompts ──────────────────────────────────────────────────────────────────

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

// ─── 1A: Chat ─────────────────────────────────────────────────────────────────

class ChatMessage {
  final bool isUser;
  final String text;
  final DateTime at;
  const ChatMessage({required this.isUser, required this.text, required this.at});
}

class ChatState {
  final List<ChatMessage> messages;
  final bool isTyping;
  final String? error;

  const ChatState({
    this.messages = const [],
    this.isTyping = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isTyping,
    String? error,
    bool clearError = false,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        isTyping: isTyping ?? this.isTyping,
        error: clearError ? null : (error ?? this.error),
      );
}

class ChatNotifier extends StateNotifier<ChatState> {
  final Ref _ref;

  ChatNotifier(this._ref) : super(const ChatState());

  Future<void> send(String text) async {
    final apiKey = _ref.read(aiKeyProvider);
    if (apiKey == null) return;

    _ref.read(arenaChatCountProvider.notifier).increment();
    final userMsg = ChatMessage(isUser: true, text: text, at: DateTime.now());
    final newMsgs = [...state.messages, userMsg];
    state = state.copyWith(messages: newMsgs, isTyping: true, clearError: true);

    try {
      final dataSummary =
          await _ref.read(mentorProvider.notifier).buildDataSummary();

      final system =
          'Eres un mentor de hábitos personal. El usuario tiene los siguientes datos:\n'
          '$dataSummary\n'
          'Responde en español, de forma concisa y accionable. Máximo 3 párrafos.';

      // Last 10 messages (including the new user message) as Groq history
      final window = newMsgs.length > 10
          ? newMsgs.sublist(newMsgs.length - 10)
          : newMsgs;
      final groqMsgs = window
          .map((m) => <String, String>{
                'role': m.isUser ? 'user' : 'assistant',
                'content': m.text,
              })
          .toList();

      final reply = await _groqChat(apiKey, system, groqMsgs, maxTokens: 512);
      final assistantMsg =
          ChatMessage(isUser: false, text: reply.trim(), at: DateTime.now());
      state = state.copyWith(
          messages: [...newMsgs, assistantMsg], isTyping: false);
    } catch (e) {
      state = state.copyWith(isTyping: false, error: e.toString());
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>(
  (ref) => ChatNotifier(ref),
);

// ─── 1C: Habit suggestion ─────────────────────────────────────────────────────

class HabitSuggestion {
  final String name;
  final String category;
  final String justification;
  final DateTime generatedAt;

  const HabitSuggestion({
    required this.name,
    required this.category,
    required this.justification,
    required this.generatedAt,
  });

  factory HabitSuggestion.fromJson(Map<String, dynamic> json) =>
      HabitSuggestion(
        name: json['name'] as String,
        category: json['category'] as String,
        justification: json['justification'] as String,
        generatedAt: DateTime.parse(json['generated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
        'justification': justification,
        'generated_at': generatedAt.toIso8601String(),
      };
}

class SuggestionNotifier
    extends StateNotifier<AsyncValue<HabitSuggestion?>> {
  static const _key = 'habit_suggestion';
  final Ref _ref;

  SuggestionNotifier(this._ref) : super(const AsyncLoading()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored != null) {
      try {
        final data = jsonDecode(stored) as Map<String, dynamic>;
        final s = HabitSuggestion.fromJson(data);
        if (DateTime.now().difference(s.generatedAt).inDays < 7) {
          state = AsyncData(s);
          return;
        }
      } catch (_) {}
    }
    await generate();
  }

  Future<void> generate() async {
    final apiKey = _ref.read(aiKeyProvider);
    if (apiKey == null) {
      state = const AsyncData(null);
      return;
    }
    state = const AsyncLoading();
    try {
      final habits = await _ref.read(habitsProvider.future);
      final categoryStats = await _ref.read(categoryStatsProvider.future);

      final habitNames = habits.map((h) => h.name).join(', ');
      final catLines = categoryStats
          .map((c) => '  ${c.category}: ${(c.rate * 100).round()}%')
          .join('\n');

      final prompt =
          'Analiza las categorías y sugiere 1 hábito nuevo. PRIORIZA la categoría '
          'con menor %. No duplicar ninguno existente.\n'
          'Responde SOLO con JSON válido: {"name":"...","category":"...","justification":"..."}\n'
          'Justification: 1-2 líneas en español con el beneficio específico.\n\n'
          'Categorías actuales (% últimos 30 días):\n$catLines\n\n'
          'Hábitos existentes: $habitNames';

      final text = await _groqChat(
        apiKey,
        'Eres un coach de hábitos. Responde SIEMPRE con JSON válido y nada más.',
        [{'role': 'user', 'content': prompt}],
        jsonMode: true,
        maxTokens: 256,
      );

      final jsonMap = jsonDecode(text) as Map<String, dynamic>;
      final suggestion = HabitSuggestion(
        name: jsonMap['name'] as String,
        category: (jsonMap['category'] as String).toLowerCase(),
        justification: jsonMap['justification'] as String,
        generatedAt: DateTime.now(),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(suggestion.toJson()));
      state = AsyncData(suggestion);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }
}

final habitSuggestionProvider =
    StateNotifierProvider<SuggestionNotifier, AsyncValue<HabitSuggestion?>>(
  (ref) => SuggestionNotifier(ref),
);

// ─── 1D: Milestone check ──────────────────────────────────────────────────────

const kMilestones = [7, 21, 30, 66, 100, 365];
const kMilestoneLabels = {
  7: 'Primera semana completada',
  21: 'Hábito en instalación',
  30: 'Un mes de disciplina',
  66: 'La ciencia dice que ya es casi automático',
  100: 'Centurión',
  365: 'Un año — eres otro.',
};

typedef MilestonePending = ({Habit habit, int milestone, String label});

final pendingMilestonesProvider =
    FutureProvider<List<MilestonePending>>((ref) async {
  final logs = await ref.watch(allLogsProvider.future);
  final habits = await ref.watch(habitsProvider.future);
  if (habits.isEmpty) return [];

  final today = DateTime.now();
  String fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // O(1) lookup set
  final completedSet = <String>{};
  for (final l in logs) {
    if (l['completed'] == true) {
      completedSet.add('${l['habit_id']}_${l['log_date']}');
    }
  }

  final pending = <MilestonePending>[];

  for (final habit in habits) {
    int streak = 0;
    for (int i = 0; i < 365; i++) {
      final date = today.subtract(Duration(days: i));
      if (!habit.daysOfWeek.contains(date.weekday)) continue;
      final done = completedSet.contains('${habit.id}_${fmt(date)}');
      if (done) {
        streak++;
      } else if (i == 0) {
        continue; // today not yet marked
      } else {
        break;
      }
    }
    for (final m in kMilestones) {
      if (streak == m && !habit.celebratedMilestones.contains(m)) {
        pending.add((
          habit: habit,
          milestone: m,
          label: kMilestoneLabels[m]!,
        ));
        break; // one milestone per habit per session
      }
    }
  }

  return pending;
});
