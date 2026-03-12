import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/category_model.dart';

class CategoryRepository {
  CategoryRepository._();
  static final CategoryRepository _instance = CategoryRepository._();

  factory CategoryRepository() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'categories';

  Stream<List<Category>> fetchCategories() {
    return _firestore
        .collection(_collection)
        .orderBy('order')
        .snapshots()
        .map((snapshot) {
          final categories = snapshot.docs
              .map((doc) => Category.fromMap(doc.id, doc.data()))
              .where((category) => category.name.isNotEmpty)
              .toList();
          categories.sort((a, b) => a.order.compareTo(b.order));
          return categories;
        });
  }
}
