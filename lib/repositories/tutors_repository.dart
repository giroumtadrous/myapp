import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/tutor_model.dart';

/// Repository for tutors data. Provides real-time streams from Firestore.
/// Uses a single shared Firestore listener to avoid duplicate calls.
///
/// Expected Firestore structure for `tutors` collection:
/// - name: String
/// - email: String
/// - bio: String
/// - subjects: List<String> (e.g. ["Mathematics", "Calculus"])
/// - hourlyRate: num
/// - rating: num
class TutorsRepository {
  TutorsRepository._();
  static final TutorsRepository _instance = TutorsRepository._();

  factory TutorsRepository() => _instance;

  static const String _collection = 'tutors';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Returns a real-time stream of tutors. Updates when tutors are added,
  /// edited, or deleted in Firestore.
  ///
/// Returns a stream of tutors, optionally filtered by one or both of
/// the provided values.  This is the central query used by all of the
/// screens and supports the following common use-cases:
///
/// * `categoryFilter` – a main category id (math, physics, etc). A tutor
///   will be returned if its `main` array contains this value. A tutor can
///   belong to multiple categories, so the same document may appear in
///   several streams.
/// * `subjectFilter` – a subject string. A tutor will be returned if its
///   `subjects` array contains the string. This allows tapping a subject
///   chip to further restrict results.
///
/// Both filters may be combined; when both are specified the query will
/// require both conditions to pass.
Stream<List<Tutor>> getTutors({
  String? categoryFilter,
  String? subjectFilter,
}) {
  Query query = _firestore.collection(_collection);

  if (categoryFilter != null) {
    query = query.where(
      'main',
      arrayContains: categoryFilter,
    );
  }

  if (subjectFilter != null) {
    query = query.where(
      'subjects',
      arrayContains: subjectFilter,
    );
  }

  return query.snapshots().map((snapshot) {
    return snapshot.docs
        .map((doc) => Tutor.fromMap(
              doc.id,
              doc.data() as Map<String, dynamic>,
            ))
        .toList();
  });
}

/// Returns a stream where the keys are the "main" categories and the values
/// are the unique subjects taught by tutors in that category.  This is useful
/// when you want to group or print subjects by their main classification.
Stream<Map<String, List<String>>> getSubjectsGroupedByMain() {
  return _firestore.collection(_collection).snapshots().map((snapshot) {
    final Map<String, Set<String>> grouped = {};
    for (final doc in snapshot.docs) {
      final tutor = Tutor.fromMap(doc.id, doc.data());
      for (final mainCat in tutor.main) {
        final set = grouped.putIfAbsent(mainCat, () => <String>{});
        set.addAll(tutor.subjects);
      }
    }

    // convert sets to sorted lists for downstream consumers
    return grouped.map((key, value) => MapEntry(key, value.toList()..sort()));
  });
}

/// Gets the weekly availability for a specific tutor.
/// Returns a map where keys are day names (lowercase) and values are lists of hours.
/// Example: {'monday': ['09:00', '10:00'], 'tuesday': ['14:00']}
/// If weeklyAvailability doesn't exist, initializes with empty arrays for all days.
Future<Map<String, List<String>>> getTutorAvailability(String tutorId) async {
  try {
    final doc = await _firestore.collection(_collection).doc(tutorId).get();
    if (!doc.exists) {
      return {};
    }

    final data = doc.data();
    if (data == null) {
      return {};
    }

    final rawAvailability =
        (data['weeklyAvailability'] ?? data['weekly_availability']);
    final availability = rawAvailability is Map
        ? Map<String, dynamic>.from(rawAvailability)
        : <String, dynamic>{};
    final result = <String, List<String>>{};

    availability.forEach((key, value) {
      if (value is List) {
        result[key.toString().toLowerCase()] =
            List<String>.from(value.map((e) => e.toString()));
      }
    });

    return result;
  } catch (e) {
    throw Exception('Failed to get tutor availability: $e');
  }
}

/// Updates the weekly availability for a specific tutor.
/// [availability] should be a map where keys are day names (lowercase) and 
/// values are lists of hours (e.g., '09:00', '10:00').
/// Only updates the weeklyAvailability field without overwriting other fields.
/// Example: {'monday': ['09:00', '10:00', '14:00'], 'tuesday': ['10:00', '11:00']}
Future<void> updateTutorAvailability(
  String tutorId,
  Map<String, List<String>> availability,
) async {
  try {
    await _firestore.collection(_collection).doc(tutorId).update({
      'weeklyAvailability': availability,
      'weekly_availability': FieldValue.delete(),
    });
  } catch (e) {
    throw Exception('Failed to update tutor availability: $e');
  }
}

/// Gets a real-time stream of a single tutor by ID.
/// Returns a stream that updates whenever the tutor document changes in Firestore.
Stream<Tutor?> getTutorById(String tutorId) {
  return _firestore.collection(_collection).doc(tutorId).snapshots().map((doc) {
    if (!doc.exists) return null;
    return Tutor.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  });
}
}
