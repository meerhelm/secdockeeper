class Folder {
  const Folder({
    required this.id,
    required this.name,
    this.color,
    required this.createdAt,
    this.documentCount = 0,
  });

  final int id;
  final String name;
  final String? color;
  final DateTime createdAt;
  final int documentCount;

  factory Folder.fromRow(Map<String, Object?> row) => Folder(
        id: row['id']! as int,
        name: row['name']! as String,
        color: row['color'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
        documentCount: (row['document_count'] as int?) ?? 0,
      );
}
