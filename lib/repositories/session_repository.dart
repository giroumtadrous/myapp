import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/session_model.dart';

class SessionRepository {
  final _firestore = FirebaseFirestore.instance;
  static const String _roomAlphabet =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_';
  final Random _random = Random.secure();

  String _generateRandomRoomName({int length = 18}) {
    final chars = List<String>.generate(
      length,
      (_) => _roomAlphabet[_random.nextInt(_roomAlphabet.length)],
    );
    return 'tutor-${chars.join()}';
  }

  bool _needsNewRoomName(String roomName, String sessionId) {
    if (roomName.isEmpty) return true;
    if (roomName == sessionId) return true;
    if (roomName.startsWith('session_')) return true;
    return false;
  }

  Future<String> ensureSessionRoomName(
    String sessionId, {
    String? existingRoomName,
  }) async {
    final current = (existingRoomName ?? '').trim();
    if (!_needsNewRoomName(current, sessionId)) {
      return current;
    }

    final sessionRef = _firestore.collection('sessions').doc(sessionId);

    return _firestore.runTransaction((tx) async {
      final snap = await tx.get(sessionRef);
      final data = snap.data() ?? <String, dynamic>{};
      final roomName = (data['roomName'] ?? data['jitsiRoomName'] ?? '')
          .toString()
          .trim();

      if (!_needsNewRoomName(roomName, sessionId)) {
        return roomName;
      }

      final generated = _generateRandomRoomName();
      tx.set(sessionRef, {
        'roomName': generated,
        'meetLink': 'https://meet.jit.si/$generated',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return generated;
    });
  }

  // ── Upcoming sessions (status in ['booked','pending'], dateTime > now) ────
  Stream<List<SessionModel>> upcomingSessions(String studentId) {
    return _firestore
        .collection('sessions')
        .where('studentId', isEqualTo: studentId)
        .where(
          'status',
          whereIn: [
            'booked',
            'confirmed',
            'pending',
            'pending_payment_verification',
            'payment_rejected',
          ],
        )
        .snapshots()
        .asyncMap(
          (snap) => _enrichWithTutorNames(
            snap.docs
                .map((d) => SessionModel.fromFirestore(d))
                .where((s) => s.dateTime.isAfter(DateTime.now()))
                .toList()
              ..sort((a, b) => a.dateTime.compareTo(b.dateTime)),
          ),
        );
  }

  // ── Past sessions (dateTime < now, any terminal status) ─────────────────
  Stream<List<SessionModel>> pastSessions(String studentId) {
    return _firestore
        .collection('sessions')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .asyncMap(
          (snap) => _enrichWithTutorNames(
            snap.docs
                .map((d) => SessionModel.fromFirestore(d))
                .where((s) => s.dateTime.isBefore(DateTime.now()))
                .toList()
              ..sort((a, b) => b.dateTime.compareTo(a.dateTime)),
          ),
        );
  }

  // ── Cancel a session — deletes the document so the slot becomes free ──────
  Future<void> cancelSession(String sessionId) async {
    await _firestore.collection('sessions').doc(sessionId).delete();
  }

  // ── TUTOR QUERIES ────────────────────────────────────────────────────────

  // ── Upcoming sessions for a tutor (dateTime >= now) ──────────────────────
  Stream<List<SessionModel>> tutorUpcomingSessions(String tutorId) {
    return _firestore
        .collection('sessions')
        .where('tutorId', isEqualTo: tutorId)
        .snapshots()
        .asyncMap(
          (snap) => _enrichWithStudentNames(
            snap.docs
                .map((d) => SessionModel.fromFirestore(d))
                .where((s) => s.dateTime.isAfter(DateTime.now()))
                .toList()
              ..sort((a, b) => a.dateTime.compareTo(b.dateTime)),
          ),
        );
  }

  // ── Past sessions for a tutor (dateTime < now) ────────────────────────────
  Stream<List<SessionModel>> tutorPastSessions(String tutorId) {
    return _firestore
        .collection('sessions')
        .where('tutorId', isEqualTo: tutorId)
        .snapshots()
        .asyncMap(
          (snap) => _enrichWithStudentNames(
            snap.docs
                .map((d) => SessionModel.fromFirestore(d))
                .where((s) => s.dateTime.isBefore(DateTime.now()))
                .toList()
              ..sort((a, b) => b.dateTime.compareTo(a.dateTime)),
          ),
        );
  }

  // ── Fetch tutor name for a single tutorId ────────────────────────────────
  Future<String> _tutorName(String tutorId) async {
    if (tutorId.isEmpty) return 'Unknown Tutor';
    final doc = await _firestore.collection('tutors').doc(tutorId).get();
    if (!doc.exists) return 'Unknown Tutor';
    final data = doc.data()!;
    return (data['name'] ?? data['displayName'] ?? 'Unknown Tutor').toString();
  }

  // ── Fetch student name for a single studentId ────────────────────────────
  Future<String> _studentName(String studentId) async {
    if (studentId.isEmpty) return 'Unknown Student';
    try {
      final doc = await _firestore.collection('users').doc(studentId).get();
      if (!doc.exists) return 'Unknown Student';
      final data = doc.data()!;
      return (data['name'] ?? data['displayName'] ?? 'Unknown Student')
          .toString();
    } catch (_) {
      return 'Unknown Student';
    }
  }

  Future<List<SessionModel>> _enrichWithTutorNames(
    List<SessionModel> sessions,
  ) async {
    // batch unique tutor IDs
    final ids = sessions.map((s) => s.tutorId).toSet();
    final names = <String, String>{};
    await Future.wait(ids.map((id) async => names[id] = await _tutorName(id)));
    return sessions
        .map((s) => s.copyWith(tutorName: names[s.tutorId]))
        .toList();
  }

  Future<List<SessionModel>> _enrichWithStudentNames(
    List<SessionModel> sessions,
  ) async {
    // batch unique student IDs
    final ids = sessions.map((s) => s.studentId).toSet();
    final names = <String, String>{};
    await Future.wait(
      ids.map((id) async => names[id] = await _studentName(id)),
    );
    // Reuse tutorName field to store student name for tutor dashboard
    return sessions
        .map((s) => s.copyWith(tutorName: names[s.studentId]))
        .toList();
  }
}
