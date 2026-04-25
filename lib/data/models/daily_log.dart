class DailyLog {
  final String id;
  final String userId;
  final String habitId;
  final DateTime logDate;
  final bool completed;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DailyLog({
    required this.id,
    required this.userId,
    required this.habitId,
    required this.logDate,
    required this.completed,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DailyLog.fromJson(Map<String, dynamic> json) => DailyLog(
        id: (json['id'] as String?) ?? '',
        userId: (json['user_id'] as String?) ?? '',
        habitId: (json['habit_id'] as String?) ?? '',
        logDate: DateTime.parse(json['log_date'] as String),
        completed: (json['completed'] as bool?) ?? false,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'habit_id': habitId,
        'log_date': logDate.toIso8601String(),
        'completed': completed,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  DailyLog copyWith({
    String? id,
    String? userId,
    String? habitId,
    DateTime? logDate,
    bool? completed,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      DailyLog(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        habitId: habitId ?? this.habitId,
        logDate: logDate ?? this.logDate,
        completed: completed ?? this.completed,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DailyLog && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
