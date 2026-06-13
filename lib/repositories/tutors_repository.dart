import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/tutor_model.dart';
import '../services/cache_service.dart';

/// Repository for tutors data. Provides real-time streams from Firestore.
/// Uses a single shared Firestore listener to avoid duplicate calls.
///
/// Expected Firestore structure for `tutors` collection:
/// - name: String
/// - email: String
/// - bio: String
/// - subjects: `List<String>` (e.g. ["Mathematics", "Calculus"])
/// - hourlyRate: num
/// - rating: num
class TutorsRepository {
  TutorsRepository._();
  static final TutorsRepository _instance = TutorsRepository._();

  factory TutorsRepository() => _instance;

  static const String _collection = 'tutors';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const int _arrayContainsAnyLimit = 30;

  Future<Map<String, _TutorComputedStats>> _loadTutorStats(
    List<Tutor> tutors,
  ) async {
    final tutorIds = tutors.map((t) => t.id).toSet();
    if (tutorIds.isEmpty) return const <String, _TutorComputedStats>{};

    final reviewsSnap = await _firestore.collection('reviews').get();
    final completedSnap = await _firestore
        .collection('sessions')
        .where('status', isEqualTo: 'completed')
        .get();

    final ratingSums = <String, double>{};
    final reviewsCount = <String, int>{};
    for (final doc in reviewsSnap.docs) {
      final data = doc.data();
      final tutorId = (data['tutorId'] ?? '').toString();
      if (!tutorIds.contains(tutorId)) continue;

      final rating = (data['rating'] as num?)?.toDouble() ?? 0;
      ratingSums[tutorId] = (ratingSums[tutorId] ?? 0) + rating;
      reviewsCount[tutorId] = (reviewsCount[tutorId] ?? 0) + 1;
    }

    final completedCount = <String, int>{};
    for (final doc in completedSnap.docs) {
      final data = doc.data();
      final tutorId = (data['tutorId'] ?? '').toString();
      if (!tutorIds.contains(tutorId)) continue;
      completedCount[tutorId] = (completedCount[tutorId] ?? 0) + 1;
    }

    final stats = <String, _TutorComputedStats>{};
    for (final tutor in tutors) {
      final count = reviewsCount[tutor.id] ?? 0;
      final sum = ratingSums[tutor.id] ?? 0;
      stats[tutor.id] = _TutorComputedStats(
        averageRating: count > 0 ? sum / count : 0,
        totalReviews: count,
        completedSessionsCount: completedCount[tutor.id] ?? 0,
      );
    }
    return stats;
  }

  Future<void> _ensureInstitutionField(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    Tutor tutor,
  ) async {
    final data = doc.data();
    final existing = (data['university'] ?? '').toString().trim();
    if (existing.isNotEmpty) return;

    final fallback = tutor.university.trim();
    if (fallback.isEmpty) return;

    unawaited(
      doc.reference.set({
        'university': fallback,
      }, SetOptions(merge: true)),
    );
  }

  Future<List<Tutor>> _withDynamicStats(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final tutors = docs.map((doc) => Tutor.fromMap(doc.id, doc.data())).toList();
    for (var i = 0; i < docs.length; i++) {
      await _ensureInstitutionField(docs[i], tutors[i]);
    }

    final stats = await _loadTutorStats(tutors);
    return tutors.map((tutor) {
      final s = stats[tutor.id];
      return tutor.copyWith(
        rating: s == null
            ? tutor.rating
            : (s.totalReviews > 0 ? s.averageRating : tutor.rating),
        totalReviews: s?.totalReviews ?? tutor.totalReviews,
        completedSessionsCount:
            s?.completedSessionsCount ?? tutor.completedSessionsCount,
      );
    }).toList();
  }

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
  }) async* {
    final hasCategoryFilter = categoryFilter != null && categoryFilter.isNotEmpty;
    final hasSubjectFilter = subjectFilter != null && subjectFilter.isNotEmpty;
    var applyCategoryLocally = false;

    Query<Map<String, dynamic>> query = _firestore.collection(_collection);
    if (hasSubjectFilter) {
      query = query.where('subjects', arrayContains: subjectFilter);
      applyCategoryLocally = hasCategoryFilter;
    } else if (hasCategoryFilter) {
      query = query.where('main', arrayContains: categoryFilter);
    }

    // 1. Hive Cache
    final cacheData = CacheService.instance.getTutors();
    bool shouldFetch = true;

    if (cacheData != null) {
      final cachedAt = cacheData['cachedAt'] as DateTime;
      final tutorsJson = cacheData['data'] as List<Map<String, dynamic>>;
      var tutors = tutorsJson.map((map) => Tutor.fromMap(map['id'], map)).toList();

      if (hasSubjectFilter) {
        tutors = tutors.where((t) => t.subjects.contains(subjectFilter)).toList();
      } else if (hasCategoryFilter) {
        tutors = tutors.where((t) => t.main.contains(categoryFilter)).toList();
      }
      
      tutors.sort((a, b) => b.rating.compareTo(a.rating));
      yield tutors;

      if (DateTime.now().difference(cachedAt).inMinutes < 30) {
        shouldFetch = false;
      }
    }

    if (!shouldFetch) return;

    // 2. Firestore stream
    await for (final snapshot in query.snapshots()) {
      var tutors = await _withDynamicStats(snapshot.docs);

      if (applyCategoryLocally) {
        tutors = tutors.where((tutor) => tutor.main.contains(categoryFilter)).toList();
      }

      tutors.sort((a, b) => b.rating.compareTo(a.rating));
      
      if (!hasSubjectFilter && !hasCategoryFilter) {
        final jsonList = tutors.map((t) {
           final m = t.toMap();
           m['id'] = t.id;
           return m;
        }).toList();
        CacheService.instance.saveTutors(jsonList);
      }

      yield tutors;
    }
  }

  Stream<List<Tutor>> getTutorsFromInstitution(String institution) {
    final target = institution.trim().toLowerCase();
    if (target.isEmpty) return Stream.value(const <Tutor>[]);

    return getTutors().map((tutors) {
      final filtered = tutors.where((tutor) {
        return tutor.university.trim().toLowerCase() == target;
      }).toList();
      filtered.sort((a, b) => b.rating.compareTo(a.rating));
      return filtered;
    });
  }

  /// Returns tutors that teach the provided [subjectIds].
  ///
  /// Uses Firestore `arrayContainsAny` for dynamic category-based filtering.
  /// If [subjectIds] exceeds Firestore's argument limit, the method falls back
  /// to a broad stream and applies the full filter client-side.
  Stream<List<Tutor>> getTutorsByAnySubjects(List<String> subjectIds) {
    final normalizedIds = subjectIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (normalizedIds.isEmpty) {
      return Stream.value(const <Tutor>[]);
    }

    if (normalizedIds.length > _arrayContainsAnyLimit) {
      return _firestore.collection(_collection).snapshots().asyncMap((snapshot) async {
        final tutors = (await _withDynamicStats(snapshot.docs))
            .where(
              (tutor) => tutor.subjects.any(
                (subject) => normalizedIds.contains(subject),
              ),
            )
            .toList();

        tutors.sort((a, b) => b.rating.compareTo(a.rating));
        return tutors;
      });
    }

    return _firestore
        .collection(_collection)
        .where('subjects', arrayContainsAny: normalizedIds)
        .snapshots()
        .asyncMap((snapshot) async {
          final tutors = await _withDynamicStats(snapshot.docs);
          tutors.sort((a, b) => b.rating.compareTo(a.rating));
          return tutors;
        });
  }

  /// Returns tutors that teach exactly [subjectId].
  Stream<List<Tutor>> getTutorsBySubject(String subjectId) {
    final value = subjectId.trim();
    if (value.isEmpty) {
      return Stream.value(const <Tutor>[]);
    }

    return _firestore
        .collection(_collection)
        .where('subjects', arrayContains: value)
        .snapshots()
        .asyncMap((snapshot) async {
          final tutors = await _withDynamicStats(snapshot.docs);
          tutors.sort((a, b) => b.rating.compareTo(a.rating));
          return tutors;
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
          result[key.toString().toLowerCase()] = List<String>.from(
            value.map((e) => e.toString()),
          );
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
    return _firestore.collection(_collection).doc(tutorId).snapshots().asyncMap((
      doc,
    ) async {
      if (!doc.exists) return null;
      final tutor = Tutor.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      final stats = await _loadTutorStats([tutor]);
      final computed = stats[tutor.id];
      return tutor.copyWith(
        rating: computed == null
            ? tutor.rating
            : (computed.totalReviews > 0
                  ? computed.averageRating
                  : tutor.rating),
        totalReviews: computed?.totalReviews ?? tutor.totalReviews,
        completedSessionsCount:
            computed?.completedSessionsCount ?? tutor.completedSessionsCount,
      );
    });
  }

  Future<void> updateTutorBio(String tutorId, String bio) async {
    try {
      await _firestore.collection(_collection).doc(tutorId).update({'bio': bio});
      await CacheService.instance.clearTutors();
    } catch (e) {
      throw Exception('Failed to update bio: $e');
    }
  }

  Future<void> updateTutorPhotoUrl(String tutorId, String photoUrl) async {
    try {
      await _firestore.collection(_collection).doc(tutorId).update({
        'photoUrl': photoUrl,
        'profileImageUrl': photoUrl,
      });
      await CacheService.instance.clearTutors();
    } catch (e) {
      throw Exception('Failed to update profile photo: $e');
    }
  }
}

class _TutorComputedStats {
  final double averageRating;
  final int totalReviews;
  final int completedSessionsCount;

  const _TutorComputedStats({
    required this.averageRating,
    required this.totalReviews,
    required this.completedSessionsCount,
  });
}
