class Note {
  final String id;
  final String notebookId;
  String title;
  String text;
  final DateTime createdAt;
  DateTime updatedAt;

  Note({
    required this.id,
    required this.notebookId,
    this.title = '',
    this.text = '',
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isEmpty => title.trim().isEmpty && text.trim().isEmpty;

  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    final firstLine = text
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => '');
    if (firstLine.isEmpty) return 'Без названия';
    return firstLine.length > 60 ? '${firstLine.substring(0, 60)}…' : firstLine;
  }

  factory Note.fromJson(Map<String, dynamic> j) => Note(
    id: j['id'] as String,
    notebookId: j['notebookId'] as String,
    title: j['title'] as String? ?? '',
    text: j['text'] as String? ?? '',
    createdAt: DateTime.parse(j['createdAt'] as String),
    updatedAt: DateTime.parse(j['updatedAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'notebookId': notebookId,
    'title': title,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
