import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/payment_model.dart';

class PaymentRepository {
  PaymentRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const List<String> blockingStatuses = <String>[
    'pending_payment_verification',
    'booked',
    'pending',
    'confirmed',
    'approved',
  ];

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

  String _meetingLink(String roomName) {
    return 'https://meet.ffmuc.net/$roomName';
  }

  Future<void> submitManualPayment({
    required String sessionId,
    required String studentId,
    required String tutorId,
    required String subject,
    required DateTime sessionDateTime,
    required String date,
    required String time,
    required String timeDisplay,
    required double amount,
    required int durationMinutes,
    required int slotCount,
    required List<String> reservedSlots,
    required DateTime transferTime,
    required String screenshotUrl,
    String? note,
  }) async {
    try {
      if (screenshotUrl.trim().isEmpty) {
        throw Exception('Screenshot URL cannot be empty.');
      }
      if (reservedSlots.isEmpty) {
        throw Exception('At least one reserved slot is required.');
      }

      final paymentRef = _firestore.collection('payments').doc();
      final sessionRef = _firestore.collection('sessions').doc(sessionId);

      final overlapping = await _firestore
          .collection('sessions')
          .where('tutorId', isEqualTo: tutorId)
          .where('date', isEqualTo: date)
          .where('status', whereIn: blockingStatuses)
          .get();

        final studentOverlapping = await _firestore
          .collection('sessions')
          .where('studentId', isEqualTo: studentId)
          .where('date', isEqualTo: date)
          .where('status', whereIn: blockingStatuses)
          .get();

      for (final doc in overlapping.docs) {
        final data = doc.data();
        final existingReservedRaw = data['reservedSlots'];
        final existingReserved = existingReservedRaw is List
            ? existingReservedRaw.map((e) => e.toString()).toSet()
            : <String>{(data['time'] ?? '').toString()};

        if (existingReserved.intersection(reservedSlots.toSet()).isNotEmpty) {
          throw Exception('This time slot is no longer available.');
        }
      }

      for (final doc in studentOverlapping.docs) {
        final data = doc.data();
        final existingReservedRaw = data['reservedSlots'];
        final existingReserved = existingReservedRaw is List
            ? existingReservedRaw.map((e) => e.toString()).toSet()
            : <String>{(data['time'] ?? '').toString()};

        if (existingReserved.intersection(reservedSlots.toSet()).isNotEmpty) {
          throw Exception(
            'You already have another session at this time. Please choose a different slot.',
          );
        }
      }

      await _firestore
          .runTransaction((tx) async {
            try {
              final existingSession = await tx.get(sessionRef);
              if (existingSession.exists) {
                final data = existingSession.data() ?? <String, dynamic>{};
                final existingStatus = (data['status'] ?? '').toString();

                // If the slot is currently in a blocking state, another student cannot use it.
                if (blockingStatuses.contains(existingStatus)) {
                  throw Exception('This time slot is no longer available.');
                }
              }
              final existingData =
                  existingSession.data() ?? <String, dynamic>{};
              final existingRoomName = (existingData['roomName'] ?? '')
                  .toString();
              final roomName = existingRoomName.isNotEmpty
                  ? existingRoomName
                  : _generateRandomRoomName();
              final existingMeetLink = (existingData['meetLink'] ?? '')
                  .toString();
              final meetLink = existingMeetLink.isNotEmpty
                  ? existingMeetLink
                  : _meetingLink(roomName);

              tx.set(paymentRef, {
                'studentId': studentId,
                'tutorId': tutorId,
                'sessionId': sessionId,
                'amount': amount,
                'durationMinutes': durationMinutes,
                'slotCount': slotCount,
                'reservedSlots': reservedSlots,
                'transferTime': Timestamp.fromDate(transferTime),
                'screenshotUrl': screenshotUrl,
                'status': 'pending',
                'note': note?.trim() ?? '',
                'createdAt': FieldValue.serverTimestamp(),
                'roomName': roomName,
              });

              final sessionData = <String, dynamic>{
                'tutorId': tutorId,
                'studentId': studentId,
                'subject': subject,
                'date': date,
                'time': time,
                'timeDisplay': timeDisplay,
                'dateTime': Timestamp.fromDate(sessionDateTime),
                'hourlyRate': amount,
                'amount': amount,
                'durationMinutes': durationMinutes,
                'slotCount': slotCount,
                'reservedSlots': reservedSlots,
                'paymentId': paymentRef.id,
                'meetLink': meetLink,
                'status': 'pending_payment_verification',
                'roomName': roomName,
              };

              if (existingSession.exists) {
                tx.update(sessionRef, {
                  ...sessionData,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
              } else {
                tx.set(sessionRef, {
                  ...sessionData,
                  'createdAt': FieldValue.serverTimestamp(),
                });
              }
            } catch (e) {
              rethrow;
            }
          })
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException(
                'Booking transaction timed out. Please try again.',
              );
            },
          );
    } on FirebaseException catch (e) {
      throw Exception(e.message ?? 'Firebase error while submitting payment.');
    } on TimeoutException catch (e) {
      throw Exception(e.message ?? 'The request timed out. Please try again.');
    } catch (_) {
      rethrow;
    }
  }

  Future<void> submitCardPayment({
    required String sessionId,
    required String studentId,
    required String tutorId,
    required String subject,
    required DateTime sessionDateTime,
    required String date,
    required String time,
    required String timeDisplay,
    required double amount,
    required int durationMinutes,
    required int slotCount,
    required List<String> reservedSlots,
    required String cardholderName,
    required String cardNumber,
  }) async {
    try {
      if (reservedSlots.isEmpty) {
        throw Exception('At least one reserved slot is required.');
      }

      final paymentRef = _firestore.collection('payments').doc();
      final sessionRef = _firestore.collection('sessions').doc(sessionId);

      final overlapping = await _firestore
          .collection('sessions')
          .where('tutorId', isEqualTo: tutorId)
          .where('date', isEqualTo: date)
          .where('status', whereIn: blockingStatuses)
          .get();

      final studentOverlapping = await _firestore
          .collection('sessions')
          .where('studentId', isEqualTo: studentId)
          .where('date', isEqualTo: date)
          .where('status', whereIn: blockingStatuses)
          .get();

      for (final doc in overlapping.docs) {
        final data = doc.data();
        final existingReservedRaw = data['reservedSlots'];
        final existingReserved = existingReservedRaw is List
            ? existingReservedRaw.map((e) => e.toString()).toSet()
            : <String>{(data['time'] ?? '').toString()};

        if (existingReserved.intersection(reservedSlots.toSet()).isNotEmpty) {
          throw Exception('This time slot is no longer available.');
        }
      }

      for (final doc in studentOverlapping.docs) {
        final data = doc.data();
        final existingReservedRaw = data['reservedSlots'];
        final existingReserved = existingReservedRaw is List
            ? existingReservedRaw.map((e) => e.toString()).toSet()
            : <String>{(data['time'] ?? '').toString()};

        if (existingReserved.intersection(reservedSlots.toSet()).isNotEmpty) {
          throw Exception(
            'You already have another session at this time. Please choose a different slot.',
          );
        }
      }

      final last4Digits = cardNumber.length >= 4
          ? cardNumber.substring(cardNumber.length - 4)
          : 'XXXX';

      await _firestore
          .runTransaction((tx) async {
            try {
              final existingSession = await tx.get(sessionRef);
              if (existingSession.exists) {
                final data = existingSession.data() ?? <String, dynamic>{};
                final existingStatus = (data['status'] ?? '').toString();

                if (blockingStatuses.contains(existingStatus)) {
                  throw Exception('This time slot is no longer available.');
                }
              }
              final existingData =
                  existingSession.data() ?? <String, dynamic>{};
              final existingRoomName = (existingData['roomName'] ?? '')
                  .toString();
              final roomName = existingRoomName.isNotEmpty
                  ? existingRoomName
                  : _generateRandomRoomName();
              final existingMeetLink = (existingData['meetLink'] ?? '')
                  .toString();
              final meetLink = existingMeetLink.isNotEmpty
                  ? existingMeetLink
                  : _meetingLink(roomName);

              tx.set(paymentRef, {
                'studentId': studentId,
                'tutorId': tutorId,
                'sessionId': sessionId,
                'amount': amount,
                'durationMinutes': durationMinutes,
                'slotCount': slotCount,
                'reservedSlots': reservedSlots,
                'transferTime': Timestamp.fromDate(DateTime.now()),
                'screenshotUrl': 'visa_mastercard',
                'status': 'approved',
                'note': 'Card Payment: Visa/Mastercard (Cardholder: $cardholderName, Card: **** **** **** $last4Digits)',
                'createdAt': FieldValue.serverTimestamp(),
                'roomName': roomName,
              });

              final sessionData = <String, dynamic>{
                'tutorId': tutorId,
                'studentId': studentId,
                'subject': subject,
                'date': date,
                'time': time,
                'timeDisplay': timeDisplay,
                'dateTime': Timestamp.fromDate(sessionDateTime),
                'hourlyRate': amount,
                'amount': amount,
                'durationMinutes': durationMinutes,
                'slotCount': slotCount,
                'reservedSlots': reservedSlots,
                'paymentId': paymentRef.id,
                'meetLink': meetLink,
                'status': 'confirmed',
                'roomName': roomName,
              };

              if (existingSession.exists) {
                tx.update(sessionRef, {
                  ...sessionData,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
              } else {
                tx.set(sessionRef, {
                  ...sessionData,
                  'createdAt': FieldValue.serverTimestamp(),
                });
              }

              tx.set(_firestore.collection('notifications').doc(), {
                'userId': studentId,
                'title': 'Payment Success',
                'message': 'Your direct card payment of \$$amount has been approved. Your session is confirmed!',
                'read': false,
                'createdAt': FieldValue.serverTimestamp(),
              });
            } catch (e) {
              rethrow;
            }
          })
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException(
                'Booking transaction timed out. Please try again.',
              );
            },
          );
    } on FirebaseException catch (e) {
      throw Exception(e.message ?? 'Firebase error while processing payment.');
    } on TimeoutException catch (e) {
      throw Exception(e.message ?? 'The request timed out. Please try again.');
    } catch (_) {
      rethrow;
    }
  }

  Stream<List<PaymentModel>> pendingPayments() {
    return _firestore
        .collection('payments')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(PaymentModel.fromFirestore).toList());
  }

  Future<void> verifyPayment({
    required String paymentId,
    required String sessionId,
    required String studentId,
    required bool approved,
  }) async {
    final paymentRef = _firestore.collection('payments').doc(paymentId);
    final sessionRef = _firestore.collection('sessions').doc(sessionId);

    final paymentStatus = approved ? 'approved' : 'rejected';
    final sessionStatus = approved ? 'confirmed' : 'payment_rejected';

    await _firestore.runTransaction((tx) async {
      final sessionSnap = await tx.get(sessionRef);
      final sessionData = sessionSnap.data() ?? <String, dynamic>{};
      final rawRoomName = (sessionData['roomName'] ?? '').toString().trim();
      final needsRandomRoom =
          rawRoomName.isEmpty ||
          rawRoomName == sessionId ||
          rawRoomName.startsWith('session_');
      final roomName = needsRandomRoom
          ? _generateRandomRoomName()
          : rawRoomName;

      tx.update(paymentRef, {
        'status': paymentStatus,
        'verifiedAt': FieldValue.serverTimestamp(),
        'roomName': roomName,
      });

      tx.update(sessionRef, {
        'status': sessionStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'roomName': roomName,
        'meetLink': _meetingLink(roomName),
      });

      tx.set(_firestore.collection('notifications').doc(), {
        'userId': studentId,
        'title': 'Payment Update',
        'message': approved
            ? 'Your payment has been approved'
            : 'Your payment has been rejected',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> userNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots();
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'read': true,
    });
  }
}
