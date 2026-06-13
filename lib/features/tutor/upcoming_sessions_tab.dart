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

        final isDark = Theme.of(context).brightness == Brightness.dark;

        if (sessions.isEmpty) {
          return Center(
            child: Text(
              'No upcoming sessions',
              style: textTheme.bodyMedium?.copyWith(
                color: isDark ? AppTheme.darkTextSecondary : Colors.grey[600],
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Upcoming Sessions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                  ),
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

  Future<void> _setMeetingLink(BuildContext context) async {
    final controller = TextEditingController(text: session.meetLink ?? '');
    final formKey = GlobalKey<FormState>();

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set Session Link'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Meeting Link / URL',
                hintText: 'https://...',
                border: OutlineInputBorder(),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter a link';
                }
                final uri = Uri.tryParse(val.trim());
                if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
                  return 'Please enter a valid URL (starting with http:// or https://)';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (updated == true && context.mounted) {
      try {
        await _sessionRepository.updateSessionMeetLink(session.id, controller.text);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meeting link updated successfully.')),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update link: $e')),
        );
      }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.fromBorderSide(AppTheme.border(isDark: isDark)),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.primary.withValues(alpha: 0.12) : const Color(0xFFEFF2FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppTheme.primary : const Color(0xFF4051B5),
                    ),
                  ),
                  Text(
                    day,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
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
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
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
                    ],
                  ),
                  if (session.meetLink != null && session.meetLink!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.link, size: 14, color: isDark ? AppTheme.primary : const Color(0xFF1D4ED8)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            session.meetLink!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppTheme.primary : const Color(0xFF1D4ED8),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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
            if (session.status == 'approved' || session.status == 'confirmed')
              IconButton(
                onPressed: () => _setMeetingLink(context),
                icon: Icon(session.meetLink != null && session.meetLink!.isNotEmpty
                    ? Icons.edit_note_rounded
                    : Icons.add_link_rounded),
                color: AppTheme.primary,
                tooltip: session.meetLink != null && session.meetLink!.isNotEmpty
                    ? 'Edit meeting link'
                    : 'Add meeting link',
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
