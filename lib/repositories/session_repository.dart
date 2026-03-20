import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/session_model.dart';

class SessionParticipant {
  final String id;
  final String name;
  final String? photoUrl;

  const SessionParticipant({
    required this.id,
    required this.name,
    this.photoUrl,
  });
}

class SessionDetailsData {
  final SessionModel session;
  final SessionParticipant tutor;
  final SessionParticipant student;

  const SessionDetailsData({
    required this.session,
    required this.tutor,
    required this.student,
  });
}

class SessionRepository {
  final _firestore = FirebaseFirestore.instance;
  static const String _roomAlphabet =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_';
  final Random _random = Random.secure();
  static const bool _enableSessionDebugLogs = true;

  bool get _canLogSessions => kDebugMode && _enableSessionDebugLogs;

  void _logFetchedDocs(String scope, QuerySnapshot snap) {
    if (!_canLogSessions) return;

    debugPrint('[Sessions][$scope] fetched ${snap.docs.length} docs');
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      debugPrint(
        '[Sessions][$scope] doc=${doc.id} '
        'status=${data['status']} '
        'duration=${data['durationMinutes'] ?? data['duration']} '
        'slotCount=${data['slotCount']} '
        'reservedSlots=${data['reservedSlots']} '
        'dateTime=${data['dateTime']} '
        'date=${data['date']} '
        'time=${data['time']}',
      );
    }
  }

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
    final normalizedStudentId = studentId.trim();
    return _firestore
        .collection('sessions')
        .where(
          'status',
          whereIn: [
            'booked',
            'confirmed',
            'approved',
            'pending',
            'pending_payment_verification',
            'payment_rejected',
          ],
        )
        .snapshots()
        .asyncMap((snap) async {
          _logFetchedDocs('student-upcoming', snap);
          final now = DateTime.now();

          final mapped = snap.docs.map((d) => SessionModel.fromFirestore(d)).toList();

          final filtered = <SessionModel>[];
          for (final session in mapped) {
            final isForStudent = session.studentId.trim() == normalizedStudentId;
            final isUpcoming = session.dateTime.isAfter(now);

            if (_canLogSessions) {
              debugPrint(
                '[Sessions][student-upcoming] parsed id=${session.id} '
                'duration=${session.durationMinutes} slotCount=${session.slotCount} '
                'dateTime=${session.dateTime.toIso8601String()} '
                'studentMatch=$isForStudent upcoming=$isUpcoming',
              );
            }

            if (isForStudent && isUpcoming) {
              filtered.add(session);
            }
          }

          filtered.sort((a, b) => a.dateTime.compareTo(b.dateTime));
          return _enrichWithTutorNames(filtered);
        });
  }

  // ── Past sessions (dateTime < now, any terminal status) ─────────────────
  Stream<List<SessionModel>> pastSessions(String studentId) {
    final normalizedStudentId = studentId.trim();
    return _firestore
        .collection('sessions')
        .snapshots()
        .asyncMap((snap) async {
          _logFetchedDocs('student-past', snap);
          final now = DateTime.now();
          final filtered = snap.docs
              .map((d) => SessionModel.fromFirestore(d))
              .where((s) => s.studentId.trim() == normalizedStudentId)
              .where((s) => s.dateTime.isBefore(now))
              .toList()
            ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
          return _enrichWithTutorNames(filtered);
        });
  }

  // ── Cancel a session by updating status (keeps historical data) ───────────
  Future<void> cancelSession(String sessionId) async {
    await _firestore.collection('sessions').doc(sessionId).update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markSessionAsCompleted(String sessionId) async {
    await _firestore.collection('sessions').doc(sessionId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<SessionModel?> sessionById(String sessionId) {
    return _firestore.collection('sessions').doc(sessionId).snapshots().map((
      doc,
    ) {
      if (!doc.exists) return null;
      return SessionModel.fromFirestore(doc);
    });
  }

  Stream<SessionDetailsData?> streamSessionDetails(String sessionId) {
    return sessionById(sessionId).asyncMap((session) async {
      if (session == null) return null;

      final tutor = await _tutorParticipant(session.tutorId);
      final student = await _studentParticipant(session.studentId);

      return SessionDetailsData(
        session: session,
        tutor: tutor,
        student: student,
      );
    });
  }

  bool canJoinSession(SessionModel session, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final normalizedStatus = session.status.toLowerCase();
    
    // Only allow joining if status is approved
    final isApproved = normalizedStatus == 'approved';
    if (!isApproved) return false;

    // Allow joining shortly before and during a session.
    final joinWindowStart = session.dateTime.subtract(
      const Duration(minutes: 15),
    );
    final joinWindowEnd = session.dateTime.add(
      Duration(minutes: session.durationMinutes),
    );
    return current.isAfter(joinWindowStart) && current.isBefore(joinWindowEnd);
  }

  // ── TUTOR QUERIES ────────────────────────────────────────────────────────

  // ── Upcoming sessions for a tutor (dateTime >= now) ──────────────────────
  Stream<List<SessionModel>> tutorUpcomingSessions(String tutorId) {
    final normalizedTutorId = tutorId.trim();
    return _firestore
        .collection('sessions')
        .snapshots()
        .asyncMap((snap) async {
          _logFetchedDocs('tutor-upcoming', snap);
          final now = DateTime.now();
          final mapped = snap.docs.map((d) => SessionModel.fromFirestore(d)).toList();

          final filtered = <SessionModel>[];
          for (final session in mapped) {
            final isForTutor = session.tutorId.trim() == normalizedTutorId;
            final isUpcoming = session.dateTime.isAfter(now);

            if (_canLogSessions) {
              debugPrint(
                '[Sessions][tutor-upcoming] parsed id=${session.id} '
                'duration=${session.durationMinutes} slotCount=${session.slotCount} '
                'dateTime=${session.dateTime.toIso8601String()} '
                'tutorMatch=$isForTutor upcoming=$isUpcoming status=${session.status}',
              );
            }

            if (isForTutor && isUpcoming) {
              filtered.add(session);
            }
          }

          filtered.sort((a, b) => a.dateTime.compareTo(b.dateTime));
          return _enrichWithStudentNames(filtered);
        });
  }

  // ── Past sessions for a tutor (dateTime < now) ────────────────────────────
  Stream<List<SessionModel>> tutorPastSessions(String tutorId) {
    final normalizedTutorId = tutorId.trim();
    return _firestore
        .collection('sessions')
        .snapshots()
        .asyncMap((snap) async {
          _logFetchedDocs('tutor-past', snap);
          final now = DateTime.now();
          final filtered = snap.docs
              .map((d) => SessionModel.fromFirestore(d))
              .where((s) => s.tutorId.trim() == normalizedTutorId)
              .where((s) => s.dateTime.isBefore(now))
              .toList()
            ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
          return _enrichWithStudentNames(filtered);
        });
  }

  Future<SessionParticipant> _tutorParticipant(String tutorId) async {
    if (tutorId.isEmpty) {
      return const SessionParticipant(id: '', name: 'Unknown Tutor');
    }

    try {
      final doc = await _firestore.collection('tutors').doc(tutorId).get();
      if (!doc.exists) {
        return SessionParticipant(id: tutorId, name: 'Unknown Tutor');
      }

      final data = doc.data() ?? <String, dynamic>{};
      return SessionParticipant(
        id: doc.id,
        name: (data['name'] ?? data['displayName'] ?? 'Unknown Tutor')
            .toString(),
        photoUrl:
            (data['photoUrl'] ?? data['profilePicture'] ?? data['avatarUrl'])
                ?.toString(),
      );
    } catch (_) {
      return SessionParticipant(id: tutorId, name: 'Unknown Tutor');
    }
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

  Future<SessionParticipant> _studentParticipant(String studentId) async {
    if (studentId.isEmpty) {
      return const SessionParticipant(id: '', name: 'Unknown Student');
    }

    try {
      final doc = await _firestore.collection('users').doc(studentId).get();
      if (!doc.exists) {
        return SessionParticipant(id: studentId, name: 'Unknown Student');
      }

      final data = doc.data() ?? <String, dynamic>{};
      return SessionParticipant(
        id: doc.id,
        name: (data['name'] ?? data['displayName'] ?? 'Unknown Student')
            .toString(),
        photoUrl:
            (data['photoUrl'] ?? data['profilePicture'] ?? data['avatarUrl'])
                ?.toString(),
      );
    } catch (_) {
      return SessionParticipant(id: studentId, name: 'Unknown Student');
    }
  }

  Future<List<SessionModel>> _enrichWithTutorNames(
    List<SessionModel> sessions,
  ) async {
    // batch unique tutor IDs
    final ids = sessions.map((s) => s.tutorId).toSet();
    final participants = <String, SessionParticipant>{};
    await Future.wait(
      ids.map((id) async => participants[id] = await _tutorParticipant(id)),
    );
    return sessions
        .map(
          (s) => s.copyWith(
            tutorName: participants[s.tutorId]?.name,
            tutorPhotoUrl: participants[s.tutorId]?.photoUrl,
          ),
        )
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
    return sessions
        .map((s) => s.copyWith(studentName: names[s.studentId]))
        .toList();
  }
}
