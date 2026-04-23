import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String id;
  final String sessionId;
  final String tutorId;
  final String studentId;
  final double rating;
  final String reviewText;
  final DateTime? createdAt;

  const ReviewModel({
    required this.id,
    required this.sessionId,
    required this.tutorId,
    required this.studentId,
    required this.rating,
    required this.reviewText,
    this.createdAt,
  });

  factory ReviewModel.fromMap(String id, Map<String, dynamic> data) {
    final created = data['createdAt'];
    return ReviewModel(
      id: id,
      sessionId: (data['sessionId'] ?? '').toString(),
      tutorId: (data['tutorId'] ?? '').toString(),
      studentId: (data['studentId'] ?? '').toString(),
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      reviewText: (data['reviewText'] ?? '').toString(),
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}
