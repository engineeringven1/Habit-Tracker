import 'package:supabase_flutter/supabase_flutter.dart';
import 'habit_repository.dart';

class SeedRepository {
  final SupabaseClient _client;
  final HabitRepository _habitRepo;

  SeedRepository(this._client)
      : _habitRepo = HabitRepository(_client);

  String get _userId => _client.auth.currentUser!.id;

  Future<void> seedIfFirstTime() async {
    if (await _habitRepo.hasHabits()) return;

    final now = DateTime.now().toUtc().toIso8601String();

    await _client.from('habits').insert([
      _h(0,  'Levantarse temprano',          'disciplina',  now),
      _h(1,  'Ejercicio 30 minutos',         'salud',       now),
      _h(2,  'Beber 2 litros de agua',       'salud',       now),
      _h(3,  'Meditación 10 minutos',        'mente',       now),
      _h(4,  'Lectura 20 minutos',           'mente',       now),
      _h(5,  'Caminar 30 minutos',           'salud',       now),
      _h(6,  'Desayuno saludable',           'nutrición',   now),
      _h(7,  'Tomar vitaminas',              'salud',       now),
      _h(8,  'Sin teléfono al despertar',    'disciplina',  now),
      _h(9,  'Planificar el día',            'disciplina',  now),
      _h(10, 'Aprender algo nuevo',          'mente',       now),
      _h(11, 'Escribir en el diario',        'mente',       now),
      _h(12, 'Estiramientos',                'salud',       now),
      _h(13, 'Gratitud: 3 cosas',            'mente',       now),
      _h(14, 'Dormir antes de las 23:00',    'disciplina',  now),
      _h(15, 'Sin alcohol',                  'restricción', now),
      _h(16, 'Sin redes sociales de noche',  'restricción', now),
      _h(17, 'Sin comida procesada',         'nutrición',   now),
      _h(18, 'Ahorrar o revisar finanzas',   'finanzas',    now),
      _h(19, 'Tiempo en familia o amigos',   'mente',       now),
    ]);

    await _client.from('reminders').insert([
      {'user_id': _userId, 'name': 'Hidratarse',       'is_active': true},
      {'user_id': _userId, 'name': 'Tomar medicación', 'is_active': true},
    ]);
  }

  Map<String, dynamic> _h(
    int order,
    String name,
    String category,
    String createdAt,
  ) =>
      {
        'user_id': _userId,
        'name': name,
        'category': category,
        'has_score': true,
        'is_active': true,
        'sort_order': order,
        'created_at': createdAt,
      };
}
