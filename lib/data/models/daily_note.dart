class DailyNote {
  final String id;
  final String userId;
  final DateTime noteDate;
  final String noteText;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DailyNote({
    required this.id,
    required this.userId,
    required this.noteDate,
    required this.noteText,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DailyNote.fromJson(Map<String, dynamic> json) => DailyNote(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        noteDate: DateTime.parse(json['note_date'] as String),
        noteText: json['note_text'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}
