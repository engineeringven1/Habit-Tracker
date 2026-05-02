class Habit {
  final String id;
  final String userId;
  final String name;
  final String category;
  final bool hasScore;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;
  final List<int> daysOfWeek; // 1=Mon … 7=Sun
  final bool notifyEnabled;
  final int  notifyStartHr; // informational start of active window (0-23)
  final int  notifyEndHr;   // hour to fire daily reminder (0-23)
  final List<int> celebratedMilestones;

  const Habit({
    required this.id,
    required this.userId,
    required this.name,
    required this.category,
    required this.hasScore,
    required this.isActive,
    required this.sortOrder,
    required this.createdAt,
    this.daysOfWeek           = const [1, 2, 3, 4, 5, 6, 7],
    this.notifyEnabled        = false,
    this.notifyStartHr        = 8,
    this.notifyEndHr          = 22,
    this.celebratedMilestones = const [],
  });

  static List<int> _parseMilestones(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((d) => (d as num).toInt()).toList();
    return [];
  }

  static List<int> _parseDays(dynamic value) {
    if (value == null) return [1, 2, 3, 4, 5, 6, 7];
    if (value is List) return value.map((d) => (d as num).toInt()).toList();
    final s = value.toString().trim();
    if (s.isEmpty) return [1, 2, 3, 4, 5, 6, 7];
    return s.split(',').map((d) => int.tryParse(d.trim()) ?? 1).toList();
  }

  factory Habit.fromJson(Map<String, dynamic> json) => Habit(
        id: json['id'] as String,
        userId: (json['user_id'] as String?) ?? '',
        name: (json['name'] as String?) ?? '',
        category: (json['category'] as String?) ?? 'general',
        hasScore: (json['has_score'] as bool?) ?? false,
        isActive: (json['is_active'] as bool?) ?? true,
        sortOrder: (json['sort_order'] as int?) ?? 0,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
        daysOfWeek:    _parseDays(json['days_of_week']),
        notifyEnabled:        (json['notify_enabled'] as bool?) ?? false,
        notifyStartHr:        (json['notify_start_hr'] as int?)  ?? 8,
        notifyEndHr:          (json['notify_end_hr']   as int?)  ?? 22,
        celebratedMilestones: _parseMilestones(json['celebrated_milestones']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'category': category,
        'has_score': hasScore,
        'is_active': isActive,
        'sort_order': sortOrder,
        'created_at': createdAt.toIso8601String(),
        'days_of_week':   daysOfWeek.join(','),
        'notify_enabled': notifyEnabled,
        'notify_start_hr': notifyStartHr,
        'notify_end_hr':   notifyEndHr,
      };

  Habit copyWith({
    String? id,
    String? userId,
    String? name,
    String? category,
    bool? hasScore,
    bool? isActive,
    int? sortOrder,
    DateTime? createdAt,
    List<int>? daysOfWeek,
    bool?      notifyEnabled,
    int?       notifyStartHr,
    int?       notifyEndHr,
    List<int>? celebratedMilestones,
  }) =>
      Habit(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        name: name ?? this.name,
        category: category ?? this.category,
        hasScore: hasScore ?? this.hasScore,
        isActive: isActive ?? this.isActive,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt ?? this.createdAt,
        daysOfWeek:           daysOfWeek           ?? this.daysOfWeek,
        notifyEnabled:        notifyEnabled        ?? this.notifyEnabled,
        notifyStartHr:        notifyStartHr        ?? this.notifyStartHr,
        notifyEndHr:          notifyEndHr          ?? this.notifyEndHr,
        celebratedMilestones: celebratedMilestones ?? this.celebratedMilestones,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Habit && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
