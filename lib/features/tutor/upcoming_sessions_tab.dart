import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/session_model.dart';
import '../../repositories/session_repository.dart';
import '../../services/jitsi_meet_service.dart';

class UpcomingSessionsTab extends StatelessWidget {
  final String tutorId;
  final SessionRepository _sessionRepository = SessionRepository();

  UpcomingSessionsTab({required this.tutorId, super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return StreamBuilder<List<SessionModel>>(
      stream: _sessionRepository.tutorUpcomingSessions(tutorId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final sessions = snapshot.data ?? [];

        if (sessions.isEmpty) {
          return Center(
            child: Text(
              'No upcoming sessions',
              style: textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            final session = sessions[index];
            return _SessionCard(session: session, showStudentName: true);
          },
        );
      },
    );
  }
}

class _SessionCard extends StatelessWidget {
  final SessionModel session;
  final bool showStudentName;
  final SessionRepository _sessionRepository = SessionRepository();

  _SessionCard({required this.session, required this.showStudentName});

  String _meetingDisplayName(User user) {
    final displayName = (user.displayName ?? '').trim();
    if (displayName.isNotEmpty) return displayName;

    final email = (user.email ?? '').trim();
    if (email.isNotEmpty) return email.split('@').first;

    return 'Tutor';
  }

  Future<void> _startMeeting(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to join the session.')),
      );
      return;
    }

    try {
      final roomName = await _sessionRepository.ensureSessionRoomName(
        session.id,
        existingRoomName: session.roomName,
      );

      await JitsiMeetService.instance.startMeeting(
        roomName: roomName,
        userName: _meetingDisplayName(currentUser),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not join session: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Format the date and time
    final dateStr =
        '${session.dateTime.year}-${session.dateTime.month.toString().padLeft(2, '0')}-${session.dateTime.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${session.dateTime.hour.toString().padLeft(2, '0')}:${session.dateTime.minute.toString().padLeft(2, '0')}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.subject,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        showStudentName
                            ? 'Student: ${session.tutorName ?? 'Unknown'}'
                            : 'Tutor: ${session.tutorName ?? 'Unknown'}',
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(session.status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    session.status,
                    style: textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  dateStr,
                  style: textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  timeStr,
                  style: textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                ),
              ],
            ),
            if (session.amount > 0) ...[
              const SizedBox(height: 12),
              Text(
                'Rate: \$${session.amount.toStringAsFixed(2)}/hour',
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.green[700],
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: session.status == 'confirmed'
                    ? () => _startMeeting(context)
                    : null,
                child: const Text('Join Session'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'booked':
      case 'confirmed':
        return Colors.blue;
      case 'pending':
      case 'pending_payment_verification':
        return Colors.orange;
      case 'payment_rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
