import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../models/session_model.dart';
import '../../repositories/payment_repository.dart';
import '../../repositories/session_repository.dart';
import '../../services/jitsi_meet_service.dart';
import '../../utils/app_transitions.dart';
import '../../utils/session_status_utils.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/fade_in_stagger.dart';
import '../../widgets/session_card.dart';
import 'manual_payment_screen.dart';
import 'session_details_screen.dart';
import 'sessions_calendar_screen.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  final SessionRepository _sessionRepository = SessionRepository();
  final PaymentRepository _paymentRepository = PaymentRepository();
  String _selectedFilter = 'All';

  final List<String> _filters = const [
    'All',
    'Pending',
    'Approved',
    'Completed',
    'Cancelled',
  ];

  String _sessionFilterLabel(SessionModel session) {
    final raw = session.status.toLowerCase();
    if (raw == 'pending' || raw.contains('pending')) return 'Pending';
    if (raw == 'approved' || raw == 'confirmed') return 'Approved';
    if (raw == 'completed') return 'Completed';
    if (raw == 'cancelled') return 'Cancelled';
    return 'All';
  }

  Future<void> _startMeeting(SessionModel session, User user) async {
    try {
      await JitsiMeetService.instance.startMeeting(
        context: context,
        sessionId: session.id,
        tutorId: session.tutorId,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not join session: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My bookings')),
        body: const Center(child: Text('Please sign in to view bookings.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
      appBar: AppBar(
        title: const Text('My Sessions'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                AppTransitions.fade(page: const SessionsCalendarScreen()),
              );
            },
            icon: const Icon(Icons.calendar_month),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top filter tabs mapped from design/sessions.html
              SizedBox(
                height: 52,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  itemBuilder: (context, index) {
                    final filter = _filters[index];
                    final selected = _selectedFilter == filter;
                    return InkWell(
                      onTap: () => setState(() => _selectedFilter = filter),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              filter,
                              style: TextStyle(
                                color: selected
                                    ? const Color(0xFF4051B5)
                                    : const Color(0xFF64748B),
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 2,
                              width: 42,
                              color: selected
                                  ? const Color(0xFF4051B5)
                                  : Colors.transparent,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _paymentRepository.userNotifications(user.uid),
                builder: (context, snapshot) {
                  final docs =
                      snapshot.data?.docs ??
                      <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                  final unread = docs.where((d) {
                    final value = d.data()['read'];
                    return value != true;
                  }).toList();

                  if (unread.isEmpty) return const SizedBox.shrink();

                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.notifications_active_outlined,
                                size: 16,
                                color: Color(0xFFB45309),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Payment Updates',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...unread.take(2).map((doc) {
                            final data = doc.data();
                            final title = (data['title'] ?? 'Payment update')
                                .toString();
                            final message = (data['message'] ?? '').toString();
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(title),
                              subtitle: Text(message),
                              trailing: TextButton(
                                onPressed: () {
                                  _paymentRepository.markNotificationRead(doc.id);
                                },
                                child: const Text('Mark read'),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              Expanded(
                child: StreamBuilder<List<SessionModel>>(
                  stream: _sessionRepository.allStudentSessions(user.uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const AppLoadingIndicator(
                        message: 'Loading your sessions...',
                      );
                    }

                    final sessions = snapshot.data ?? [];
                    final filteredSessions = _selectedFilter == 'All'
                        ? sessions
                        : sessions
                              .where(
                                (session) =>
                                    _sessionFilterLabel(session) == _selectedFilter,
                              )
                              .toList();
                    if (sessions.isEmpty) {
                      return Center(
                        child: Text(
                          'No sessions yet.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      );
                    }

                    if (filteredSessions.isEmpty) {
                      return Center(
                        child: Text(
                          'No $_selectedFilter sessions found.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.only(top: 2, bottom: 12),
                      itemCount: filteredSessions.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final session = filteredSessions[index];
                        final canJoin = _sessionRepository.canJoinSession(
                          session,
                        );
                        final isPast = session.dateTime.isBefore(DateTime.now());

                        return FadeInStagger(
                          index: index,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SessionCard(
                                tutorName: session.tutorName ?? session.tutorId,
                                subject: session.subject,
                                date: DateFormat.yMMMd().format(
                                  session.dateTime,
                                ),
                                sessionDateTime: session.dateTime,
                                timeRange: DateFormat.jm().format(
                                  session.dateTime,
                                ),
                                statusLabel: sessionStatusLabel(session.status),
                                statusColor: sessionStatusColor(session.status),
                                isActive: false,
                                isPast: isPast,
                                durationMinutes: session.durationMinutes,
                                onTap: () {
                                  Navigator.of(context).push(
                                    AppTransitions.slideFromRight(
                                      page: SessionDetailsScreen(
                                        sessionId: session.id,
                                      ),
                                    ),
                                  );
                                },
                                onJoinMeet: canJoin
                                    ? () => _startMeeting(session, user)
                                    : null,
                              ),
                              if (session.status ==
                                  'pending_payment_verification')
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Waiting for payment confirmation',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: Colors.orange[800],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              if (session.status == 'payment_rejected')
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        AppTransitions.slideFromRight(
                                          page: ManualPaymentScreen(
                                            sessionId: session.id,
                                            tutorId: session.tutorId,
                                            subject: session.subject,
                                            date: DateFormat(
                                              'yyyy-MM-dd',
                                            ).format(session.dateTime),
                                            time: DateFormat(
                                              'HH:mm',
                                            ).format(session.dateTime),
                                            timeDisplay: DateFormat.jm().format(
                                              session.dateTime,
                                            ),
                                            sessionDateTime: session.dateTime,
                                            amount: session.amount,
                                            durationMinutes:
                                                session.durationMinutes,
                                            slotCount: session.slotCount,
                                            reservedSlots:
                                                session.reservedSlots.isNotEmpty
                                                ? session.reservedSlots
                                                : <String>[
                                                    DateFormat(
                                                      'HH:mm',
                                                    ).format(session.dateTime),
                                                  ],
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.upload_file_outlined,
                                    ),
                                    label: const Text(
                                      'Upload Correct Payment Proof',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
