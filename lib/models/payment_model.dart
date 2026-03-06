import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentModel {
  final String id;
  final String studentId;
  final String tutorId;
  final String sessionId;
  final double amount;
  final DateTime transferTime;
  final String screenshotUrl;
  final String status;
  final String? note;
  final DateTime? createdAt;

  const PaymentModel({
    required this.id,
    required this.studentId,
    required this.tutorId,
    required this.sessionId,
    required this.amount,
    required this.transferTime,
    required this.screenshotUrl,
    required this.status,
    this.note,
    this.createdAt,
  });

  factory PaymentModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final transferRaw = data['transferTime'];
    final createdRaw = data['createdAt'];

    DateTime transferTime;
    if (transferRaw is Timestamp) {
      transferTime = transferRaw.toDate();
    } else if (transferRaw is String) {
      transferTime = DateTime.tryParse(transferRaw) ?? DateTime.now();
    } else {
      transferTime = DateTime.now();
    }

    DateTime? createdAt;
    if (createdRaw is Timestamp) {
      createdAt = createdRaw.toDate();
    }

    return PaymentModel(
      id: doc.id,
      studentId: (data['studentId'] ?? '').toString(),
      tutorId: (data['tutorId'] ?? '').toString(),
      sessionId: (data['sessionId'] ?? '').toString(),
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      transferTime: transferTime,
      screenshotUrl: (data['screenshotUrl'] ?? '').toString(),
      status: (data['status'] ?? 'pending').toString(),
      note: data['note']?.toString(),
      createdAt: createdAt,
    );
  }
}
