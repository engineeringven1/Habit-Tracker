class Reminder {
  final String id;
  final String userId;
  final String name;
  final bool   isActive;
  final bool   notifyEnabled;
  final int    notifyHr; // 0-23

  const Reminder({
    required this.id,
    required this.userId,
    required this.name,
    required this.isActive,
    this.notifyEnabled = false,
    this.notifyHr      = 9,
  });

  factory Reminder.fromJson(Map<String, dynamic> json) => Reminder(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        name: json['name'] as String,
        isActive:      json['is_active'] as bool,
        notifyEnabled: (json['notify_enabled'] as bool?) ?? false,
        notifyHr:      (json['notify_hr']      as int?)  ?? 9,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'is_active':      isActive,
        'notify_enabled': notifyEnabled,
        'notify_hr':      notifyHr,
      };

  Reminder copyWith({
    String? id,
    String? userId,
    String? name,
    bool?   isActive,
    bool?   notifyEnabled,
    int?    notifyHr,
  }) =>
      Reminder(
        id:            id            ?? this.id,
        userId:        userId        ?? this.userId,
        name:          name          ?? this.name,
        isActive:      isActive      ?? this.isActive,
        notifyEnabled: notifyEnabled ?? this.notifyEnabled,
        notifyHr:      notifyHr      ?? this.notifyHr,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Reminder && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
