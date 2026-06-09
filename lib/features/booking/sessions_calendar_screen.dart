import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../models/session_model.dart';
import '../../repositories/session_repository.dart';
import '../../utils/app_transitions.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/pressable_scale.dart';
import '../../theme/app_theme.dart';
import 'session_details_screen.dart';

class SessionsCalendarScreen extends StatefulWidget {
  const SessionsCalendarScreen({super.key});

  @override
  State<SessionsCalendarScreen> createState() => _SessionsCalendarScreenState();
}

class _SessionsCalendarScreenState extends State<SessionsCalendarScreen> {
  final SessionRepository _sessionRepository = SessionRepository();
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<SessionModel> _sessionsForDay(List<SessionModel> sessions, DateTime day) {
    return sessions.where((session) => _sameDay(session.dateTime, day)).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  void _showDaySessions(DateTime day, List<SessionModel> sessions, bool isDark) {
    if (sessions.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat.yMMMMd().format(day),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: sessions.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    final isPast = session.dateTime.isBefore(DateTime.now());
                    return PressableScale(
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(this.context).push(
                          AppTransitions.slideFromRight(
                            page: SessionDetailsScreen(sessionId: session.id),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.fromBorderSide(
                            BorderSide(
                              color: AppTheme.primary.withValues(alpha: isDark ? 0.22 : 0.14),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              color: isPast
                                  ? (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)
                                  : AppTheme.primary,
                              size: 20,
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
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${DateFormat.jm().format(session.dateTime)} • ${session.tutorName ?? session.tutorId}',
                                    style: TextStyle(
                                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
        body: const Center(
          child: Text('Please sign in to view your sessions calendar.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
        title: const Text('Sessions Calendar'),
      ),
      body: StreamBuilder<List<SessionModel>>(
        stream: _sessionRepository.allStudentSessions(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingIndicator(
              message: 'Loading session calendar...',
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final sessions = snapshot.data ?? <SessionModel>[];

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Calendar Container
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.fromBorderSide(
                      BorderSide(
                        color: AppTheme.primary.withValues(alpha: isDark ? 0.22 : 0.14),
                      ),
                    ),
                  ),
                  child: TableCalendar<SessionModel>(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2035, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) =>
                        _selectedDay != null && _sameDay(_selectedDay!, day),
                    eventLoader: (day) => _sessionsForDay(sessions, day),
                    calendarFormat: CalendarFormat.month,
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: TextStyle(
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                      leftChevronIcon: Icon(
                        Icons.chevron_left_rounded,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                      ),
                      rightChevronIcon: Icon(
                        Icons.chevron_right_rounded,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                      ),
                    ),
                    daysOfWeekStyle: DaysOfWeekStyle(
                      weekdayStyle: TextStyle(
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      weekendStyle: TextStyle(
                        color: AppTheme.primary.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    calendarStyle: CalendarStyle(
                      outsideDaysVisible: false,
                      defaultTextStyle: TextStyle(
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      weekendTextStyle: TextStyle(
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      selectedDecoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      todayDecoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                    ),
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, day, daySessions) {
                        if (daySessions.isEmpty) return const SizedBox.shrink();
                        final hasUpcoming = daySessions.any(
                          (s) => !s.dateTime.isBefore(DateTime.now()),
                        );

                        return Positioned(
                          bottom: 6,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: hasUpcoming ? AppTheme.primary : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                        );
                      },
                      defaultBuilder: (context, day, focusedDay) {
                        final daySessions = _sessionsForDay(sessions, day);
                        if (daySessions.isEmpty) return null;
                        final hasUpcoming = daySessions.any(
                          (s) => !s.dateTime.isBefore(DateTime.now()),
                        );
                        return Center(
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: hasUpcoming
                                  ? AppTheme.primary.withValues(alpha: 0.14)
                                  : (isDark ? AppTheme.darkBackground : const Color(0xFFF1F5F9)),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: hasUpcoming
                                    ? AppTheme.primary.withValues(alpha: 0.3)
                                    : Colors.transparent,
                                width: 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${day.day}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: hasUpcoming
                                    ? AppTheme.primary
                                    : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                      final daySessions = _sessionsForDay(sessions, selectedDay);
                      _showDaySessions(selectedDay, daySessions, isDark);
                    },
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Selected Day Header / Title
                if (_selectedDay != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10, left: 4),
                      child: Text(
                        'Sessions for ${DateFormat('MMMM d').format(_selectedDay!)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                    ),
                  ),

                // Sessions List below calendar
                Expanded(
                  child: _selectedDay == null
                      ? Center(
                          child: Text(
                            'Tap a date to view sessions.',
                            style: TextStyle(
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                            ),
                          ),
                        )
                      : Builder(
                          builder: (context) {
                            final daySessions = _sessionsForDay(sessions, _selectedDay!);
                            if (daySessions.isEmpty) {
                              return Center(
                                child: Text(
                                  'No sessions scheduled on this date.',
                                  style: TextStyle(
                                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                  ),
                                ),
                              );
                            }

                            return ListView.separated(
                              itemCount: daySessions.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final session = daySessions[index];
                                final isPast = session.dateTime.isBefore(DateTime.now());
                                return PressableScale(
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
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.fromBorderSide(
                                        BorderSide(
                                          color: AppTheme.primary.withValues(alpha: isDark ? 0.22 : 0.14),
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.event_note_rounded,
                                          color: isPast
                                              ? (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)
                                              : AppTheme.primary,
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
                                                 fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${DateFormat.jm().format(session.dateTime)} • ${session.tutorName ?? session.tutorId}',
                                                style: TextStyle(
                                                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
