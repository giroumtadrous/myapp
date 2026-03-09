import 'package:cloud_firestore/cloud_firestore.dart';

class SessionModel {
  final String id;
  final String tutorId;
  final String studentId;
  final String subject;
  final DateTime dateTime;
  final String status;
  final String roomName;
  final String? meetLink;
  final String? paymentId;
  final double amount;
  final String? tutorName; // populated after join with tutors collection

  const SessionModel({
    required this.id,
    required this.tutorId,
    required this.studentId,
    required this.subject,
    required this.dateTime,
    required this.status,
    required this.roomName,
    this.meetLink,
    this.paymentId,
    this.amount = 0,
    this.tutorName,
  });

  factory SessionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    DateTime dt;
    final rawDate = data['dateTime'] ?? data['date'];
    if (rawDate is Timestamp) {
      dt = rawDate.toDate();
    } else if (rawDate is String) {
      // Support "yyyy-MM-dd" strings combined with optional time field
      final timeStr = (data['time'] as String?) ?? '00:00';
      dt = DateTime.tryParse('${rawDate}T$timeStr:00') ?? DateTime.now();
    } else {
      dt = DateTime.now();
    }

    return SessionModel(
      id: doc.id,
      tutorId: (data['tutorId'] ?? data['tutorID'] ?? '').toString(),
      studentId: (data['studentId'] ?? '').toString(),
      subject: (data['subject'] ?? '').toString(),
      dateTime: dt,
      status: (data['status'] ?? 'pending').toString(),
        roomName: (data['roomName'] ?? data['jitsiRoomName'] ?? '').toString(),
      meetLink: data['meetLink']?.toString(),
      paymentId: data['paymentId']?.toString(),
      amount:
          (data['hourlyRate'] as num?)?.toDouble() ??
          (data['amount'] as num?)?.toDouble() ??
          0,
    );
  }

  SessionModel copyWith({String? tutorName}) {
    return SessionModel(
      id: id,
      tutorId: tutorId,
      studentId: studentId,
      subject: subject,
      dateTime: dateTime,
      status: status,
      roomName: roomName,
      meetLink: meetLink,
      paymentId: paymentId,
      amount: amount,
      tutorName: tutorName ?? this.tutorName,
    );
  }
}
