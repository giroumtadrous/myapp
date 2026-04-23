import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/review_model.dart';

class TutorReviewStats {
  final double averageRating;
  final int totalReviews;

  const TutorReviewStats({
    required this.averageRating,
    required this.totalReviews,
  });
}

class ReviewsRepository {
  ReviewsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<bool> hasReviewForSession(String sessionId) async {
    final reviewDoc = await _firestore.collection('reviews').doc(sessionId).get();
    return reviewDoc.exists;
  }

  Future<void> submitReview({
    required String sessionId,
    required String tutorId,
    required String studentId,
    required double rating,
    required String reviewText,
  }) async {
    final reviewRef = _firestore.collection('reviews').doc(sessionId);
    final sessionRef = _firestore.collection('sessions').doc(sessionId);

    await _firestore.runTransaction((tx) async {
      final sessionSnap = await tx.get(sessionRef);
      if (!sessionSnap.exists) {
        throw Exception('Session not found.');
      }

      final sessionData = sessionSnap.data() ?? <String, dynamic>{};
      final sessionStatus = (sessionData['status'] ?? '').toString().toLowerCase();
      final sessionStudentId = (sessionData['studentId'] ?? '').toString();
      final sessionTutorId = (sessionData['tutorId'] ?? '').toString();

      if (sessionStatus != 'completed') {
        throw Exception('Only completed sessions can be reviewed.');
      }
      if (sessionStudentId != studentId) {
        throw Exception('Only the attending student can review this session.');
      }
      if (sessionTutorId != tutorId) {
        throw Exception('Tutor mismatch for this session review.');
      }

      final existingReview = await tx.get(reviewRef);
      if (existingReview.exists) {
        throw Exception('This session has already been reviewed.');
      }

      tx.set(reviewRef, {
        'sessionId': sessionId,
        'tutorId': tutorId,
        'studentId': studentId,
        'rating': rating,
        'reviewText': reviewText,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Stream<List<ReviewModel>> tutorReviews(String tutorId) {
    return _firestore
        .collection('reviews')
        .where('tutorId', isEqualTo: tutorId)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ReviewModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<TutorReviewStats> getTutorReviewStats(String tutorId) async {
    final snap = await _firestore
        .collection('reviews')
        .where('tutorId', isEqualTo: tutorId)
        .get();

    if (snap.docs.isEmpty) {
      return const TutorReviewStats(averageRating: 0, totalReviews: 0);
    }

    var sum = 0.0;
    for (final doc in snap.docs) {
      sum += (doc.data()['rating'] as num?)?.toDouble() ?? 0;
    }

    return TutorReviewStats(
      averageRating: sum / snap.docs.length,
      totalReviews: snap.docs.length,
    );
  }
}
