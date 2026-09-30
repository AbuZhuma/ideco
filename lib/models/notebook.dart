class Notebook {
  final String id;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;

  Notebook({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Notebook.fromJson(Map<String, dynamic> j) => Notebook(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    createdAt: DateTime.parse(j['createdAt'] as String),
    updatedAt: DateTime.parse(j['updatedAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
