import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/session_model.dart';

class SessionRepository {
  final _firestore = FirebaseFirestore.instance;

  // ── Upcoming sessions (status in ['booked','pending'], dateTime > now) ────
  Stream<List<SessionModel>> upcomingSessions(String studentId) {
    return _firestore
        .collection('sessions')
        .where('studentId', isEqualTo: studentId)
        .where('status', whereIn: [
          'booked',
          'pending',
          'pending_payment_verification',
          'payment_rejected',
        ])
        .snapshots()
        .asyncMap((snap) => _enrichWithTutorNames(
              snap.docs
                  .map((d) => SessionModel.fromFirestore(d))
                  .where((s) => s.dateTime.isAfter(DateTime.now()))
                  .toList()
                ..sort((a, b) => a.dateTime.compareTo(b.dateTime)),
            ));
  }

  // ── Past sessions (dateTime < now, any terminal status) ─────────────────
  Stream<List<SessionModel>> pastSessions(String studentId) {
    return _firestore
        .collection('sessions')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .asyncMap((snap) => _enrichWithTutorNames(
              snap.docs
                  .map((d) => SessionModel.fromFirestore(d))
                  .where((s) => s.dateTime.isBefore(DateTime.now()))
                  .toList()
                ..sort((a, b) => b.dateTime.compareTo(a.dateTime)),
            ));
  }

  // ── Cancel a session — deletes the document so the slot becomes free ──────
  Future<void> cancelSession(String sessionId) async {
    await _firestore.collection('sessions').doc(sessionId).delete();
  }

  // ── Fetch tutor name for a single tutorId ────────────────────────────────
  Future<String> _tutorName(String tutorId) async {
    if (tutorId.isEmpty) return 'Unknown Tutor';
    final doc = await _firestore.collection('tutors').doc(tutorId).get();
    if (!doc.exists) return 'Unknown Tutor';
    final data = doc.data()!;
    return (data['name'] ?? data['displayName'] ?? 'Unknown Tutor').toString();
  }

  Future<List<SessionModel>> _enrichWithTutorNames(
      List<SessionModel> sessions) async {
    // batch unique tutor IDs
    final ids = sessions.map((s) => s.tutorId).toSet();
    final names = <String, String>{};
    await Future.wait(
      ids.map((id) async => names[id] = await _tutorName(id)),
    );
    return sessions
        .map((s) => s.copyWith(tutorName: names[s.tutorId]))
        .toList();
  }
}
