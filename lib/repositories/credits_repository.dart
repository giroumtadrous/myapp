import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/session_model.dart';

class CreditsRepository {
  CreditsRepository._();
  static final CreditsRepository instance = CreditsRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Student Wallet Streams ──
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchStudentWalletSummary(String studentId) {
    return _firestore
        .collection('students')
        .doc(studentId)
        .collection('wallet')
        .doc('summary')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchStudentTransactions(String studentId) {
    return _firestore
        .collection('students')
        .doc(studentId)
        .collection('wallet')
        .doc('summary')
        .collection('credit_transactions')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ── Strike count stream for tutor ──
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchTutorDocument(String tutorId) {
    return _firestore.collection('tutors').doc(tutorId).snapshots();
  }

  // ── Atomic Credit Adjustments ──
  Future<void> adjustCredits({
    required String studentId,
    required double amount,
    required String type, // "refund" | "usage"
    required String reason,
    required String sessionId,
    Transaction? activeTx,
  }) async {
    final summaryRef = _firestore
        .collection('students')
        .doc(studentId)
        .collection('wallet')
        .doc('summary');

    final txRef = _firestore
        .collection('students')
        .doc(studentId)
        .collection('wallet')
        .doc('summary')
        .collection('credit_transactions')
        .doc();

    final now = DateTime.now();
    final expiresAt = now.add(const Duration(days: 180)); // 6 months

    final txData = {
      'amount': amount,
      'type': type,
      'reason': reason,
      'sessionId': sessionId,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
    };

    if (activeTx != null) {
      final summarySnap = await activeTx.get(summaryRef);
      final double currentCredits = (summarySnap.data()?['credits'] as num?)?.toDouble() ?? 0;
      final double currentEarned = (summarySnap.data()?['totalCreditsEarned'] as num?)?.toDouble() ?? 0;
      final double currentUsed = (summarySnap.data()?['totalCreditsUsed'] as num?)?.toDouble() ?? 0;

      double newCredits = currentCredits;
      double newEarned = currentEarned;
      double newUsed = currentUsed;

      if (type == 'refund') {
        newCredits += amount;
        newEarned += amount;
      } else if (type == 'usage') {
        newCredits = (newCredits - amount).clamp(0.0, double.infinity);
        newUsed += amount;
      }

      activeTx.set(summaryRef, {
        'credits': newCredits,
        'totalCreditsEarned': newEarned,
        'totalCreditsUsed': newUsed,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      activeTx.set(txRef, txData);
    } else {
      await _firestore.runTransaction((tx) async {
        final summarySnap = await tx.get(summaryRef);
        final double currentCredits = (summarySnap.data()?['credits'] as num?)?.toDouble() ?? 0;
        final double currentEarned = (summarySnap.data()?['totalCreditsEarned'] as num?)?.toDouble() ?? 0;
        final double currentUsed = (summarySnap.data()?['totalCreditsUsed'] as num?)?.toDouble() ?? 0;

        double newCredits = currentCredits;
        double newEarned = currentEarned;
        double newUsed = currentUsed;

        if (type == 'refund') {
          newCredits += amount;
          newEarned += amount;
        } else if (type == 'usage') {
          newCredits = (newCredits - amount).clamp(0.0, double.infinity);
          newUsed += amount;
        }

        tx.set(summaryRef, {
          'credits': newCredits,
          'totalCreditsEarned': newEarned,
          'totalCreditsUsed': newUsed,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        tx.set(txRef, txData);
      });
    }
  }

  // ── Helper to notify user ──
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String message,
    String? type,
    String? sessionId,
    Transaction? activeTx,
  }) async {
    final notifRef = _firestore.collection('notifications').doc();
    final notifData = {
      'userId': userId,
      'title': title,
      'message': message,
      'type': type,
      'sessionId': sessionId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (activeTx != null) {
      activeTx.set(notifRef, notifData);
    } else {
      await _firestore.collection('notifications').add(notifData);
    }
  }

  // ── Student Cancellation ──
  Future<void> cancelSessionByStudent({
    required String sessionId,
    required String studentId,
    required String reason,
  }) async {
    final sessionRef = _firestore.collection('sessions').doc(sessionId);

    // ── Pre-read all refs before the transaction (reads must precede writes
    //    on Flutter Web / Firestore JS SDK).
    final studentSummaryRef = _firestore
        .collection('students')
        .doc(studentId)
        .collection('wallet')
        .doc('summary');

    try {
      await _firestore.runTransaction((tx) async {
        // ── READS FIRST ─────────────────────────────────────────────────────
        final sessionSnap = await tx.get(sessionRef);
        if (!sessionSnap.exists) throw Exception('Session not found');

        final session = SessionModel.fromFirestore(sessionSnap);

        if (session.status != 'confirmed' && session.status != 'approved') {
          throw Exception(
            'Only confirmed or approved sessions can be cancelled. Got status: ${session.status}',
          );
        }

        final now = DateTime.now();
        final diff = session.dateTime.difference(now);
        final minutesRemaining = diff.inMinutes;

        if (minutesRemaining < 60) {
          throw Exception('Cancellation is locked less than 1 hour before the session');
        }

        double refundPercentage = 0.0;
        if (minutesRemaining >= 12 * 60) {
          refundPercentage = 1.0;
        } else if (minutesRemaining >= 3 * 60) {
          refundPercentage = 0.5;
        }

        final isGroup = session.type == 'group';
        final double refundAmount;
        final double tutorEarnings;

        DocumentReference<Map<String, dynamic>>? tutorWalletRef;
        DocumentReference<Map<String, dynamic>>? tutorTxRef;

        if (!isGroup) {
          refundAmount = session.amount * refundPercentage;
          tutorEarnings = session.amount * (1.0 - refundPercentage);

          if (tutorEarnings > 0) {
            tutorWalletRef = _firestore
                .collection('tutors')
                .doc(session.tutorId)
                .collection('wallet')
                .doc('summary');
            tutorTxRef = _firestore
                .collection('tutors')
                .doc(session.tutorId)
                .collection('wallet')
                .doc('transactions')
                .collection('items')
                .doc();
          }
        } else {
          refundAmount = session.pricePerStudent * refundPercentage;
          tutorEarnings = 0.0;
        }

        // ── WRITES ──────────────────────────────────────────────────────────
        if (isGroup) {
          final updatedStudentIds = List<String>.from(session.studentIds)..remove(studentId);
          tx.update(sessionRef, {
            'studentIds': updatedStudentIds,
            'currentStudents': updatedStudentIds.length,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          tx.update(sessionRef, {
            'status': 'cancelled',
            'cancelledBy': 'student',
            'cancelledAt': FieldValue.serverTimestamp(),
            'cancellationReason': reason,
            'refundAmount': refundAmount,
            'refundStatus': refundPercentage > 0 ? 'issued' : 'none',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // Student credit refund
        if (refundAmount > 0) {
          tx.set(studentSummaryRef, {
            'credits': FieldValue.increment(refundAmount),
            'totalCreditsEarned': FieldValue.increment(refundAmount),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          final txRef = studentSummaryRef.collection('credit_transactions').doc();
          final expiresAt = now.add(const Duration(days: 180));
          tx.set(txRef, {
            'amount': refundAmount,
            'type': 'refund',
            'reason': isGroup
                ? 'Cancelled group session (${diff.inHours}h before start)'
                : 'Cancelled session (${diff.inHours}h before start)',
            'sessionId': sessionId,
            'createdAt': FieldValue.serverTimestamp(),
            'expiresAt': Timestamp.fromDate(expiresAt),
          });
        }

        // Tutor earnings (solo only)
        if (!isGroup && tutorEarnings > 0 && tutorWalletRef != null && tutorTxRef != null) {
          tx.set(tutorWalletRef, {
            'totalEarned': FieldValue.increment(tutorEarnings),
            'pendingPayout': FieldValue.increment(tutorEarnings),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          tx.set(tutorTxRef, {
            'sessionId': sessionId,
            'amount': tutorEarnings,
            'status': 'pending_payout',
            'createdAt': FieldValue.serverTimestamp(),
            'subject': session.subject,
            'studentId': studentId,
          });
        }

        // Notifications (set, no reads needed)
        tx.set(_firestore.collection('notifications').doc(), {
          'userId': studentId,
          'title': 'Session Cancelled',
          'message': isGroup
              ? 'You have cancelled your slot. Refund issued: EGP ${refundAmount.toStringAsFixed(0)}'
              : 'Your session has been cancelled. Refund issued: EGP ${refundAmount.toStringAsFixed(0)}',
          'type': 'cancellation',
          'sessionId': sessionId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (!isGroup) {
          tx.set(_firestore.collection('notifications').doc(), {
            'userId': session.tutorId,
            'title': 'Session Cancelled by Student',
            'message': 'Student cancelled. You earned: EGP ${tutorEarnings.toStringAsFixed(0)}',
            'type': 'cancellation',
            'sessionId': sessionId,
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e, stack) {
      debugPrint('[CreditsRepository] cancelSessionByStudent failed: $e\n$stack');
      rethrow;
    }
  }

  // ── Tutor Cancellation ──
  Future<void> cancelSessionByTutor({
    required String sessionId,
    required String tutorId,
    required String reason,
  }) async {
    final sessionRef = _firestore.collection('sessions').doc(sessionId);
    final tutorRef = _firestore.collection('tutors').doc(tutorId);

    await _firestore.runTransaction((tx) async {
      // ── READS FIRST ─────────────────────────────────────────────────────
      final sessionSnap = await tx.get(sessionRef);
      if (!sessionSnap.exists) throw Exception('Session not found');
      final session = SessionModel.fromFirestore(sessionSnap);

      final tutorSnap = await tx.get(tutorRef);

      // Prepare student wallet refs
      final refundShare = session.type == 'group' ? session.pricePerStudent : session.amount;
      final studentSummaryRefs = <String, DocumentReference<Map<String, dynamic>>>{};
      for (final sId in session.studentIds) {
        final ref = _firestore
            .collection('students')
            .doc(sId)
            .collection('wallet')
            .doc('summary');
        studentSummaryRefs[sId] = ref;
      }

      // ── WRITES ──────────────────────────────────────────────────────────
      tx.update(sessionRef, {
        'status': 'cancelled',
        'cancelledBy': 'tutor',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancellationReason': reason,
        'refundAmount': session.amount,
        'refundStatus': 'issued',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final now = DateTime.now();
      final expiresAt = now.add(const Duration(days: 180));

      for (final sId in session.studentIds) {
        final summaryRef = studentSummaryRefs[sId]!;

        tx.set(summaryRef, {
          'credits': FieldValue.increment(refundShare),
          'totalCreditsEarned': FieldValue.increment(refundShare),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        tx.set(summaryRef.collection('credit_transactions').doc(), {
          'amount': refundShare,
          'type': 'refund',
          'reason': 'Tutor cancelled the session',
          'sessionId': sessionId,
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(expiresAt),
        });

        tx.set(_firestore.collection('notifications').doc(), {
          'userId': sId,
          'title': 'Session Cancelled by Tutor',
          'message': 'Tutor cancelled. A 100% refund of EGP ${refundShare.toStringAsFixed(0)} has been issued.',
          'type': 'cancellation',
          'sessionId': sessionId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      int strikeCount = (tutorSnap.data()?['strikeCount'] as num?)?.toInt() ?? 0;
      strikeCount += 1;
      final bool suspend = strikeCount >= 3;

      tx.set(tutorRef, {
        'strikeCount': strikeCount,
        'isSuspended': suspend,
        if (suspend) 'suspendedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      tx.set(_firestore.collection('notifications').doc(), {
        'userId': tutorId,
        'title': 'Session Cancelled / Strike Issued',
        'message': suspend
            ? 'You cancelled a session. You now have 3 strikes and your account has been SUSPENDED.'
            : 'You cancelled a session. A strike has been issued to your profile (Strikes: $strikeCount/3).',
        'type': 'strike',
        'sessionId': sessionId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ── Tutor No-Show ──
  Future<void> reportNoShow({
    required String sessionId,
    required String studentId,
  }) async {
    final sessionRef = _firestore.collection('sessions').doc(sessionId);

    await _firestore.runTransaction((tx) async {
      // ── READS FIRST ─────────────────────────────────────────────────────
      final sessionSnap = await tx.get(sessionRef);
      if (!sessionSnap.exists) throw Exception('Session not found');
      final session = SessionModel.fromFirestore(sessionSnap);

      final now = DateTime.now();
      final allowedTime = session.dateTime.add(const Duration(minutes: 15));
      if (now.isBefore(allowedTime)) {
        throw Exception('You can only report a no-show 15 minutes after the session starts');
      }

      final tutorRef = _firestore.collection('tutors').doc(session.tutorId);
      final tutorSnap = await tx.get(tutorRef);

      final refundShare = session.type == 'group' ? session.pricePerStudent : session.amount;
      final studentSummaryRefs = <String, DocumentReference<Map<String, dynamic>>>{};
      for (final sId in session.studentIds) {
        final ref = _firestore
            .collection('students')
            .doc(sId)
            .collection('wallet')
            .doc('summary');
        studentSummaryRefs[sId] = ref;
      }

      // ── WRITES ──────────────────────────────────────────────────────────
      tx.update(sessionRef, {
        'status': 'no_show',
        'noShowReported': true,
        'noShowReportedAt': FieldValue.serverTimestamp(),
        'refundAmount': session.amount,
        'refundStatus': 'issued',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final expiresAt = now.add(const Duration(days: 180));

      for (final sId in session.studentIds) {
        final summaryRef = studentSummaryRefs[sId]!;

        tx.set(summaryRef, {
          'credits': FieldValue.increment(refundShare),
          'totalCreditsEarned': FieldValue.increment(refundShare),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        tx.set(summaryRef.collection('credit_transactions').doc(), {
          'amount': refundShare,
          'type': 'refund',
          'reason': 'Tutor No-Show',
          'sessionId': sessionId,
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(expiresAt),
        });

        tx.set(_firestore.collection('notifications').doc(), {
          'userId': sId,
          'title': 'Tutor No-Show Reported',
          'message': 'Your report is confirmed. A 100% refund of EGP ${refundShare.toStringAsFixed(0)} has been issued.',
          'type': 'no_show',
          'sessionId': sessionId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      int strikeCount = (tutorSnap.data()?['strikeCount'] as num?)?.toInt() ?? 0;
      strikeCount += 1;
      final bool suspend = strikeCount >= 3;

      tx.set(tutorRef, {
        'strikeCount': strikeCount,
        'isSuspended': suspend,
        if (suspend) 'suspendedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      tx.set(_firestore.collection('notifications').doc(), {
        'userId': session.tutorId,
        'title': 'No-Show Reported / Strike Issued',
        'message': suspend
            ? 'A student reported a no-show. You now have 3 strikes and your account has been SUSPENDED.'
            : 'A student reported a no-show. A strike has been issued to your profile (Strikes: $strikeCount/3).',
        'type': 'strike',
        'sessionId': sessionId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ── Disputes ──
  Future<void> raiseDispute({
    required String sessionId,
    required String reason,
  }) async {
    final sessionRef = _firestore.collection('sessions').doc(sessionId);

    await _firestore.runTransaction((tx) async {
      final sessionSnap = await tx.get(sessionRef);
      if (!sessionSnap.exists) throw Exception('Session not found');

      final session = SessionModel.fromFirestore(sessionSnap);
      final now = DateTime.now();

      // Ensure disputes can only be raised up to 24 hours after completion
      if (session.status != 'completed') {
        throw Exception('Disputes can only be raised for completed sessions');
      }

      final completionTime = session.dateTime.add(Duration(minutes: session.durationMinutes));
      final limit = completionTime.add(const Duration(hours: 24));
      if (now.isAfter(limit)) {
        throw Exception('Disputes can only be raised up to 24 hours after session completion');
      }

      tx.update(sessionRef, {
        'status': 'disputed',
        'disputeReason': reason,
        'disputedAt': FieldValue.serverTimestamp(),
        'disputeStatus': 'open',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await sendNotification(
        userId: session.tutorId,
        title: 'Session Disputed',
        message: 'A student has disputed your completed session. Admin will review.',
        type: 'dispute',
        sessionId: sessionId,
        activeTx: tx,
      );
    });
  }

  Future<void> resolveDispute({
    required String sessionId,
    required String resolution, // "full_credits" | "partial_credits" | "no_refund"
    double? customRefundAmount,
  }) async {
    final sessionRef = _firestore.collection('sessions').doc(sessionId);

    await _firestore.runTransaction((tx) async {
      final sessionSnap = await tx.get(sessionRef);
      if (!sessionSnap.exists) throw Exception('Session not found');

      final session = SessionModel.fromFirestore(sessionSnap);
      
      double studentRefund = 0.0;
      if (resolution == 'full_credits') {
        studentRefund = session.amount;
      } else if (resolution == 'partial_credits') {
        studentRefund = customRefundAmount ?? 0.0;
      }

      tx.update(sessionRef, {
        'status': 'completed', // resolve back to completed but with dispute flags
        'disputeStatus': 'resolved',
        'disputeResolution': resolution,
        'disputeResolvedAt': FieldValue.serverTimestamp(),
        'disputeRefundAmount': studentRefund,
        'refundAmount': studentRefund,
        'refundStatus': studentRefund > 0 ? 'issued' : 'none',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (studentRefund > 0) {
        // Refund the student(s) - distribute refund appropriately if it's group
        if (session.type == 'group') {
          final share = studentRefund / session.studentIds.length;
          for (final sId in session.studentIds) {
            await adjustCredits(
              studentId: sId,
              amount: share,
              type: 'refund',
              reason: 'Dispute resolved: $resolution',
              sessionId: sessionId,
              activeTx: tx,
            );

            await sendNotification(
              userId: sId,
              title: 'Dispute Resolved',
              message: 'The dispute was resolved. EGP ${share.toStringAsFixed(0)} credits have been refunded.',
              type: 'dispute_resolved',
              sessionId: sessionId,
              activeTx: tx,
            );
          }
        } else {
          await adjustCredits(
            studentId: session.studentId,
            amount: studentRefund,
            type: 'refund',
            reason: 'Dispute resolved: $resolution',
            sessionId: sessionId,
            activeTx: tx,
          );

          await sendNotification(
            userId: session.studentId,
            title: 'Dispute Resolved',
            message: 'The dispute was resolved. EGP ${studentRefund.toStringAsFixed(0)} credits have been refunded.',
            type: 'dispute_resolved',
            sessionId: sessionId,
            activeTx: tx,
          );
        }
      } else {
        // Notify student of no refund
        for (final sId in session.studentIds) {
          await sendNotification(
            userId: sId,
            title: 'Dispute Resolved',
            message: 'The dispute was resolved. No credit refund was issued.',
            type: 'dispute_resolved',
            sessionId: sessionId,
            activeTx: tx,
          );
        }
      }

      // Notify tutor
      await sendNotification(
        userId: session.tutorId,
        title: 'Dispute Resolved',
        message: 'The dispute on your session has been resolved: $resolution.',
        type: 'dispute_resolved',
        sessionId: sessionId,
        activeTx: tx,
      );
    });
  }
}
