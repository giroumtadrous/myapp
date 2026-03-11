import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/session_model.dart';
import '../../repositories/session_repository.dart';
import '../../utils/app_transitions.dart';
import '../../utils/session_status_utils.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/fade_in_stagger.dart';
import '../../widgets/session_card.dart';
import '../booking/session_details_screen.dart';

class PastSessionsTab extends StatelessWidget {
  final String tutorId;
  final SessionRepository _sessionRepository = SessionRepository();

  PastSessionsTab({required this.tutorId, super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return StreamBuilder<List<SessionModel>>(
      stream: _sessionRepository.tutorPastSessions(tutorId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingIndicator(message: 'Loading history...');
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final sessions = snapshot.data ?? [];

        if (sessions.isEmpty) {
          return Center(
            child: Text(
              'No past sessions',
              style: textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            final session = sessions[index];
            return FadeInStagger(
              index: index,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SessionCard(session: session, showStudentName: true),
              ),
            );
          },
        );
      },
    );
  }
}

class _SessionCard extends StatelessWidget {
  final SessionModel session;
  final bool showStudentName;

  const _SessionCard({required this.session, required this.showStudentName});

  @override
  Widget build(BuildContext context) {
    final personLabel = showStudentName
        ? 'Student: ${session.studentName ?? 'Unknown'}'
        : 'Tutor: ${session.tutorName ?? 'Unknown'}';

    return SessionCard(
      tutorName: personLabel,
      subject: session.subject,
      date: DateFormat.yMMMd().format(session.dateTime),
      timeRange: DateFormat.jm().format(session.dateTime),
      statusLabel: sessionStatusLabel(session.status),
      statusColor: sessionStatusColor(session.status),
      isActive: false,
      isPast: true,
      onTap: () {
        Navigator.of(context).push(
          AppTransitions.slideFromRight(
            page: SessionDetailsScreen(sessionId: session.id),
          ),
        );
      },
    );
  }
}
