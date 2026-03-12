class Category {
  final String id;
  final String name;
  final int order;

  const Category({
    required this.id,
    required this.name,
    required this.order,
  });

  factory Category.fromMap(String id, Map<String, dynamic> data) {
    return Category(
      id: id,
      name: (data['name'] ?? '').toString().trim(),
      order: _toInt(data['order']),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
