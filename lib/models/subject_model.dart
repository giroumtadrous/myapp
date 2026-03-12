class Subject {
  final String id;
  final String name;
  final String categoryId;

  const Subject({
    required this.id,
    required this.name,
    required this.categoryId,
  });

  factory Subject.fromMap(String id, Map<String, dynamic> data) {
    return Subject(
      id: id,
      name: (data['name'] ?? '').toString().trim(),
      categoryId: (data['categoryId'] ?? '').toString().trim(),
    );
  }
}
