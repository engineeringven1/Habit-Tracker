class MentorInsight {
  final String id;
  final String blockType;
  final String content;
  final DateTime generatedAt;

  const MentorInsight({
    required this.id,
    required this.blockType,
    required this.content,
    required this.generatedAt,
  });

  factory MentorInsight.fromMap(Map<String, dynamic> m) => MentorInsight(
        id: m['id'] as String,
        blockType: m['block_type'] as String,
        content: m['content'] as String,
        generatedAt: DateTime.parse(m['generated_at'] as String).toLocal(),
      );
}
