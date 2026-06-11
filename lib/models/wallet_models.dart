import 'package:cloud_firestore/cloud_firestore.dart';

class WalletSummary {
  final double totalEarned;
  final double pendingPayout;
  final double paidOut;

  const WalletSummary({
    this.totalEarned = 0,
    this.pendingPayout = 0,
    this.paidOut = 0,
  });

  factory WalletSummary.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists) return const WalletSummary();
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return WalletSummary(
      totalEarned: (data['totalEarned'] as num?)?.toDouble() ?? 0,
      pendingPayout: (data['pendingPayout'] as num?)?.toDouble() ?? 0,
      paidOut: (data['paidOut'] as num?)?.toDouble() ?? 0,
    );
  }
}

class WalletTransaction {
  final String id;
  final String sessionId;
  final double amount;
  final String status;
  final DateTime? createdAt;
  final String? subject;
  final String? studentId;
  final String? studentName;

  const WalletTransaction({
    required this.id,
    required this.sessionId,
    required this.amount,
    required this.status,
    this.createdAt,
    this.subject,
    this.studentId,
    this.studentName,
  });

  factory WalletTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final createdRaw = data['createdAt'];
    return WalletTransaction(
      id: doc.id,
      sessionId: (data['sessionId'] ?? '').toString(),
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      status: (data['status'] ?? 'pending_payout').toString(),
      createdAt: createdRaw is Timestamp ? createdRaw.toDate() : null,
      subject: data['subject']?.toString(),
      studentId: data['studentId']?.toString(),
    );
  }
}

class PayoutRequest {
  final String id;
  final String tutorId;
  final double amount;
  final String status;
  final DateTime? createdAt;
  final DateTime? paidAt;
  final String? tutorName;

  const PayoutRequest({
    required this.id,
    required this.tutorId,
    required this.amount,
    required this.status,
    this.createdAt,
    this.paidAt,
    this.tutorName,
  });

  factory PayoutRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final createdRaw = data['createdAt'];
    final paidRaw = data['paidAt'];
    return PayoutRequest(
      id: doc.id,
      tutorId: (data['tutorId'] ?? '').toString(),
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      status: (data['status'] ?? 'pending').toString(),
      createdAt: createdRaw is Timestamp ? createdRaw.toDate() : null,
      paidAt: paidRaw is Timestamp ? paidRaw.toDate() : null,
      tutorName: data['tutorName']?.toString(),
    );
  }
}
