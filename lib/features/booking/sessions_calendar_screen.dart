import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../models/session_model.dart';
import '../../repositories/session_repository.dart';
import '../../utils/app_transitions.dart';
import '../../widgets/app_loading_indicator.dart';
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

  void _showDaySessions(DateTime day, List<SessionModel> sessions) {
    if (sessions.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat.yMMMMd().format(day),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              ...sessions.map((session) {
                final isPast = session.dateTime.isBefore(DateTime.now());
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(this.context).push(
                      AppTransitions.slideFromRight(
                        page: SessionDetailsScreen(sessionId: session.id),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isPast ? const Color(0xFFF8FAFC) : const Color(0xFFEFF4FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isPast ? const Color(0xFFE2E8F0) : const Color(0xFFCAD5FF),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          color: isPast ? const Color(0xFF94A3B8) : const Color(0xFF4051B5),
                        ),
                        const SizedBox(width: 10),
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
                                '${DateFormat.jm().format(session.dateTime)} • ${session.tutorName ?? session.tutorId}',
                                style: const TextStyle(color: Color(0xFF475569)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view your sessions calendar.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Sessions Calendar')),
      body: StreamBuilder<List<SessionModel>>(
        stream: _sessionRepository.allStudentSessions(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingIndicator(
              message: 'Loading session calendar...',
            );
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final sessions = snapshot.data ?? <SessionModel>[];

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
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
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, day, daySessions) {
                        if (daySessions.isEmpty) return const SizedBox.shrink();
                        final hasUpcoming = daySessions.any(
                          (s) => !s.dateTime.isBefore(DateTime.now()),
                        );

                        return Positioned(
                          bottom: 6,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: hasUpcoming
                                  ? Theme.of(context).colorScheme.primary
                                  : const Color(0xFF9CA3AF),
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
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: hasUpcoming
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primary
                                    .withValues(alpha: 0.14)
                                  : const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${day.day}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: hasUpcoming
                                    ? Theme.of(context).colorScheme.primary
                                    : const Color(0xFF64748B),
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
                      _showDaySessions(selectedDay, daySessions);
                    },
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _selectedDay == null
                      ? const Center(
                          child: Text('Tap a date to view sessions.'),
                        )
                      : Builder(
                          builder: (context) {
                            final daySessions = _sessionsForDay(sessions, _selectedDay!);
                            if (daySessions.isEmpty) {
                              return const Center(
                                child: Text('No sessions on this date.'),
                              );
                            }

                            return ListView.separated(
                              itemBuilder: (context, index) {
                                final session = daySessions[index];
                                final isPast = session.dateTime.isBefore(DateTime.now());
                                return ListTile(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      AppTransitions.slideFromRight(
                                        page: SessionDetailsScreen(sessionId: session.id),
                                      ),
                                    );
                                  },
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: isPast
                                          ? const Color(0xFFE2E8F0)
                                          : const Color(0xFFCAD5FF),
                                    ),
                                  ),
                                  tileColor: isPast
                                      ? const Color(0xFFF8FAFC)
                                      : const Color(0xFFEFF4FF),
                                  leading: Icon(
                                    Icons.event_note,
                                    color: isPast
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF4051B5),
                                  ),
                                  title: Text(session.subject),
                                  subtitle: Text(
                                    '${DateFormat.jm().format(session.dateTime)} • ${session.tutorName ?? session.tutorId}',
                                  ),
                                );
                              },
                              separatorBuilder: (context, index) => const SizedBox(height: 8),
                              itemCount: daySessions.length,
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
