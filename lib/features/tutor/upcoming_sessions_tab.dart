import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/session_model.dart';
import '../../repositories/session_repository.dart';
import '../../services/jitsi_meet_service.dart';
import '../../utils/app_transitions.dart';
import '../../utils/meeting_utils.dart';
import '../../utils/session_status_utils.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/fade_in_stagger.dart';
import '../booking/session_details_screen.dart';

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
          return const AppLoadingIndicator(message: 'Loading sessions...');
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final sessions = snapshot.data ?? [];
        for (final s in sessions) {
          debugPrint(
            '[Dashboard][tutor-upcoming] session=${s.id} status=${s.status} '
            'duration=${s.durationMinutes} slotCount=${s.slotCount} '
            'dateTime=${s.dateTime.toIso8601String()}',
          );
        }

        if (sessions.isEmpty) {
          return Center(
            child: Text(
              'No upcoming sessions',
              style: textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Upcoming Sessions',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                TextButton(onPressed: () {}, child: const Text('View All')),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(sessions.length, (index) {
              final session = sessions[index];
              return FadeInStagger(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _UpcomingSessionTile(session: session),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _UpcomingSessionTile extends StatelessWidget {
  final SessionModel session;
  final SessionRepository _sessionRepository = SessionRepository();

  _UpcomingSessionTile({required this.session});

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
        userName: resolveMeetingDisplayName(currentUser, fallback: 'Tutor'),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not join session: $e')));
    }
  }

  Future<void> _markAsCompleted(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as Completed'),
        content: const Text('Are you sure you want to mark this session as completed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    try {
      await _sessionRepository.markSessionAsCompleted(session.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session marked as completed')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark as completed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MMM').format(session.dateTime).toUpperCase();
    final day = DateFormat('d').format(session.dateTime);
    final subtitle =
        'with ${session.studentName ?? 'Unknown'}  ${DateFormat.jm().format(session.dateTime)}';

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.of(context).push(
          AppTransitions.slideFromRight(
            page: SessionDetailsScreen(sessionId: session.id),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF2FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    date,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4051B5),
                    ),
                  ),
                  Text(
                    day,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.subject,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: session.durationMinutes >= 120
                              ? const Color(0xFFFFF1D6)
                              : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          'Duration: ${session.durationMinutes} min',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: session.durationMinutes >= 120
                                ? const Color(0xFFB45309)
                                : const Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: sessionStatusColor(session.status).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      sessionStatusLabel(session.status),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: sessionStatusColor(session.status),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: session.status == 'approved' || session.status == 'confirmed'
                  ? () => _startMeeting(context)
                  : null,
              icon: const Icon(Icons.video_call_outlined),
              color: const Color(0xFF4051B5),
              tooltip: 'Join session',
            ),
            if (session.status == 'approved' || session.status == 'confirmed')
              IconButton(
                onPressed: () => _markAsCompleted(context),
                icon: const Icon(Icons.check_circle_outlined),
                color: Colors.green,
                tooltip: 'Mark as completed',
              ),
          ],
        ),
      ),
    );
  }
}
