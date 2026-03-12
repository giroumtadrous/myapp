import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/subject_model.dart';

class SubjectRepository {
  SubjectRepository._();
  static final SubjectRepository _instance = SubjectRepository._();

  factory SubjectRepository() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'subjects';

  Stream<List<Subject>> fetchSubjects() {
    return _firestore.collection(_collection).snapshots().map((snapshot) {
      final subjects = snapshot.docs
          .map((doc) => Subject.fromMap(doc.id, doc.data()))
          .where((subject) => subject.name.isNotEmpty)
          .toList();
      subjects.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return subjects;
    });
  }

  Stream<List<Subject>> fetchSubjectsByCategory(String categoryId) {
    return _firestore
        .collection(_collection)
        .where('categoryId', isEqualTo: categoryId)
        .snapshots()
        .map((snapshot) {
          final subjects = snapshot.docs
              .map((doc) => Subject.fromMap(doc.id, doc.data()))
              .where((subject) => subject.name.isNotEmpty)
              .toList();
          subjects.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          return subjects;
        });
  }
}
