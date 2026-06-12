import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class SosAcceptDialog extends StatelessWidget {
  final String subject;
  final String sosRequestId;
  final VoidCallback onAccept;
  final VoidCallback onIgnore;

  const SosAcceptDialog({
    super.key,
    required this.subject,
    required this.sosRequestId,
    required this.onAccept,
    required this.onIgnore,
  });

  /// Shows the SOS accept dialog and handles the accept/ignore logic.
  ///
  /// Call this from anywhere when a tutor receives an SOS notification.
  static Future<void> show({
    required BuildContext context,
    required String subject,
    required String sosRequestId,
  }) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (ctx) {
        return SosAcceptDialog(
          subject: subject,
          sosRequestId: sosRequestId,
          onAccept: () async {
            Navigator.of(ctx).pop();
            await _acceptSosRequest(
              context: context,
              sosRequestId: sosRequestId,
              subject: subject,
            );
          },
          onIgnore: () => Navigator.of(ctx).pop(),
        );
      },
    );
  }

  static Future<void> _acceptSosRequest({
    required BuildContext context,
    required String sosRequestId,
    required String subject,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Get the SOS request to find studentId
      final sosDoc = await firestore
          .collection('sos_requests')
          .doc(sosRequestId)
          .get();
      if (!sosDoc.exists) return;

      final sosData = sosDoc.data()!;
      final studentId = (sosData['studentId'] ?? '').toString();

      // Get tutor's tutorId (their doc in tutors collection)
      final tutorQuery = await firestore
          .collection('tutors')
          .where('authUid', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      String tutorId = currentUser.uid;
      if (tutorQuery.docs.isNotEmpty) {
        tutorId = tutorQuery.docs.first.id;
      }

      // Update SOS request to matched
      await firestore.collection('sos_requests').doc(sosRequestId).update({
        'status': 'matched',
        'matchedTutorId': tutorId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create a new session
      // Generate session ID in same format: tutorId_year_month_day_time
      final now = DateTime.now();
      final sessionId =
          '${tutorId}_${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';

      // Use .doc(sessionId).set() instead of .add()
      final sessionRef = firestore.collection('sessions').doc(sessionId);
      await sessionRef.set({
        'type': 'sos',
        'tutorId': tutorId,
        'studentId': studentId,
        'studentIds': [studentId],
        'subject': subject,
        'status': 'pending_payment',
        'dateTime': FieldValue.serverTimestamp(),
        'durationMinutes': 60,
        'amount': 0,
        'roomName': 'sos-$sosRequestId',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Link session to SOS request
      await firestore.collection('sos_requests').doc(sosRequestId).update({
        'sessionId': sessionRef.id,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SOS session created! ✓'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept SOS request: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withValues(alpha: 0.15),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Emergency icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFF97316)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                  blurRadius: 20,
                ),
              ],
            ),
            child: const Center(
              child: Text('🆘', style: TextStyle(fontSize: 32)),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'SOS Tutoring Request',
            style: TextStyle(
              color: isDark
                  ? AppTheme.darkTextPrimary
                  : AppTheme.lightTextPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            'A student needs help with $subject right now',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onIgnore,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                    side: BorderSide(
                      color: isDark
                          ? AppTheme.primary.withValues(alpha: 0.3)
                          : AppTheme.primary.withValues(alpha: 0.2),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Ignore',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Accept',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
