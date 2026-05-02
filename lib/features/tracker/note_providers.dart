import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/daily_note.dart';
import '../../data/repositories/note_repository.dart';
import 'tracker_providers.dart';

final noteRepositoryProvider = Provider<NoteRepository>(
  (ref) => NoteRepository(Supabase.instance.client),
);

class DailyNoteNotifier extends StateNotifier<AsyncValue<DailyNote?>> {
  final NoteRepository _repo;
  final DateTime date;

  DailyNoteNotifier(this._repo, {required this.date})
      : super(const AsyncLoading()) {
    _load();
  }

  Future<void> _load() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.getNoteForDate(date));
  }

  Future<void> save(String text) async {
    await _repo.upsertNote(date, text.trim());
    await _load();
  }
}

final dailyNoteProvider =
    StateNotifierProvider<DailyNoteNotifier, AsyncValue<DailyNote?>>(
  (ref) {
    final date = ref.watch(selectedDateProvider);
    return DailyNoteNotifier(ref.read(noteRepositoryProvider), date: date);
  },
);

// Used by the mentor to get context from the last N days of notes.
final recentNotesProvider = FutureProvider.family<List<DailyNote>, int>(
  (ref, days) => ref.read(noteRepositoryProvider).getRecentNotes(days),
);
