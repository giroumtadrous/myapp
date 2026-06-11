import 'package:cloud_firestore/cloud_firestore.dart';

class StudentProgress {
  final String subject;
  final int totalSessions;
  final int totalMinutes;
  final DateTime? lastSessionAt;
  final List<String> tutorsUsed;

  const StudentProgress({
    required this.subject,
    this.totalSessions = 0,
    this.totalMinutes = 0,
    this.lastSessionAt,
    this.tutorsUsed = const [],
  });

  factory StudentProgress.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final lastRaw = data['lastSessionAt'];
    return StudentProgress(
      subject: doc.id,
      totalSessions: (data['totalSessions'] as num?)?.toInt() ?? 0,
      totalMinutes: (data['totalMinutes'] as num?)?.toInt() ?? 0,
      lastSessionAt: lastRaw is Timestamp ? lastRaw.toDate() : null,
      tutorsUsed: (data['tutorsUsed'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  double get totalHours => totalMinutes / 60.0;
}
