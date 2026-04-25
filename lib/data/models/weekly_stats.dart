class WeeklyStats {
  final String userId;
  final DateTime weekStart;
  final int completedCount;
  final int totalPossible;
  final double scorePercentage;

  const WeeklyStats({
    required this.userId,
    required this.weekStart,
    required this.completedCount,
    required this.totalPossible,
    required this.scorePercentage,
  });

  factory WeeklyStats.fromJson(Map<String, dynamic> json) => WeeklyStats(
        userId: json['user_id'] as String,
        weekStart: DateTime.parse(json['week_start'] as String),
        completedCount: json['completed_count'] as int,
        totalPossible: json['total_possible'] as int,
        scorePercentage: (json['score_percentage'] as num).toDouble(),
      );

  double get completionRate =>
      totalPossible == 0 ? 0.0 : completedCount / totalPossible;
}
