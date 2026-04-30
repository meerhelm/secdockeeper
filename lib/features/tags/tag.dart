class Tag {
  const Tag({required this.id, required this.name, this.color, required this.createdAt});

  final int id;
  final String name;
  final String? color;
  final DateTime createdAt;

  factory Tag.fromRow(Map<String, Object?> row) => Tag(
        id: row['id']! as int,
        name: row['name']! as String,
        color: row['color'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
      );
}
