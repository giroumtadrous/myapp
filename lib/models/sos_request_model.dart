import 'package:cloud_firestore/cloud_firestore.dart';

class SosRequestModel {
  final String id;
  final String studentId;
  final String subject;
  final String status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? matchedTutorId;
  final String? sessionId;

  const SosRequestModel({
    required this.id,
    required this.studentId,
    required this.subject,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.matchedTutorId,
    this.sessionId,
  });

  factory SosRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final createdRaw = data['createdAt'];
    final expiresRaw = data['expiresAt'];
    return SosRequestModel(
      id: doc.id,
      studentId: (data['studentId'] ?? '').toString(),
      subject: (data['subject'] ?? '').toString(),
      status: (data['status'] ?? 'searching').toString(),
      createdAt:
          createdRaw is Timestamp ? createdRaw.toDate() : DateTime.now(),
      expiresAt: expiresRaw is Timestamp
          ? expiresRaw.toDate()
          : DateTime.now().add(const Duration(hours: 1)),
      matchedTutorId: data['matchedTutorId']?.toString(),
      sessionId: data['sessionId']?.toString(),
    );
  }
}
