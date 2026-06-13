import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/session_model.dart';
import '../../repositories/session_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_transitions.dart';
import '../../utils/session_status_utils.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/fade_in_stagger.dart';
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
        final isDark = Theme.of(context).brightness == Brightness.dark;

        if (sessions.isEmpty) {
          return Center(
            child: Text(
              'No past sessions',
              style: textTheme.bodyMedium?.copyWith(
                color: isDark ? AppTheme.darkTextSecondary : Colors.grey[600],
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            Text(
              'Past Sessions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 10),
            ...List.generate(sessions.length, (index) {
              final session = sessions[index];
              return FadeInStagger(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PastSessionTile(session: session),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _PastSessionTile extends StatelessWidget {
  final SessionModel session;

  const _PastSessionTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.fromBorderSide(AppTheme.border(isDark: isDark)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: sessionStatusColor(session.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    sessionStatusLabel(session.status).toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: sessionStatusColor(session.status),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('MMM d, y').format(session.dateTime),
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              session.subject,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Student: ${session.studentName ?? 'Unknown'}',
              style: TextStyle(
                color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: session.durationMinutes >= 120
                    ? (isDark ? const Color(0xFF78350F).withValues(alpha: 0.2) : const Color(0xFFFFF1D6))
                    : (isDark ? AppTheme.primary.withValues(alpha: 0.12) : const Color(0xFFEFF6FF)),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                'Duration: ${session.durationMinutes} min',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: session.durationMinutes >= 120
                      ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309))
                      : (isDark ? AppTheme.primary : const Color(0xFF1D4ED8)),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              DateFormat.jm().format(session.dateTime),
              style: TextStyle(
                color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
