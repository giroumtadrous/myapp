import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/session_model.dart';
import '../../repositories/payment_repository.dart';
import '../../repositories/session_repository.dart';
import '../../repositories/tutors_repository.dart';
import '../../services/jitsi_meet_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_transitions.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/zelp_ui_components.dart';
import 'manual_payment_screen.dart';
import 'session_details_screen.dart';
import 'sessions_calendar_screen.dart';
import 'zelp_tutor_profile_screen.dart';

class ZelpSessionsScreen extends StatefulWidget {
  const ZelpSessionsScreen({super.key});

  @override
  State<ZelpSessionsScreen> createState() => _ZelpSessionsScreenState();
}

class _ZelpSessionsScreenState extends State<ZelpSessionsScreen> {
  final SessionRepository _sessionRepository = SessionRepository();
  final PaymentRepository _paymentRepository = PaymentRepository();
  final TutorsRepository _tutorsRepository = TutorsRepository();

  final List<String> _filters = const [
    'All',
    'Pending',
    'Approved',
    'Payment Rejected',
  ];
  int _filterIndex = 0;

  String _sessionFilterLabel(SessionModel session) {
    final raw = session.status.toLowerCase();
    if (raw == 'payment_rejected') return 'Payment Rejected';
    if (raw == 'pending' ||
        raw == 'pending_payment_verification' ||
        raw.contains('pending'))
      return 'Pending';
    if (raw == 'approved' || raw == 'confirmed' || raw == 'booked')
      return 'Approved';
    return 'All';
  }

  Future<void> _startMeeting(
    BuildContext context,
    SessionModel session,
    User user,
  ) async {
    try {
      await JitsiMeetService.instance.startMeeting(
        context: context,
        sessionId: session.id,
        tutorId: session.tutorId,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not join session: $e')));
    }
  }

  Future<void> _confirmCancel(
    BuildContext context,
    SessionModel session,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Session'),
        content: const Text('Are you sure you want to cancel this session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _sessionRepository.cancelSession(session.id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Session cancelled.')));
      }
    }
  }

  Future<void> _rebookSession(
    BuildContext context,
    SessionModel session,
  ) async {
    try {
      final tutor = await _tutorsRepository.getTutorById(session.tutorId).first;
      if (!context.mounted) return;

      if (tutor == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tutor profile is unavailable right now.'),
          ),
        );
        return;
      }

      Navigator.of(context).push(
        AppTransitions.slideFromRight(
          page: ZelpTutorProfileScreen(tutor: tutor),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open tutor profile: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: const Text('My Sessions')),
        body: const Center(child: Text('Please sign in to view sessions.')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('My Sessions'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(
                context,
              ).push(AppTransitions.fade(page: const SessionsCalendarScreen()));
            },
            icon: const Icon(Icons.calendar_month),
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                AppTransitions.fade(
                  page: PastSessionsScreen(
                    sessionRepository: _sessionRepository,
                    tutorsRepository: _tutorsRepository,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.history),
            tooltip: 'Past sessions',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Payment Updates Box (if any)
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _paymentRepository.userNotifications(currentUser.uid),
              builder: (context, snapshot) {
                final docs =
                    snapshot.data?.docs ??
                    <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                final unread = docs
                    .where((d) => d.data()['read'] != true)
                    .toList();

                if (unread.isEmpty) return const SizedBox.shrink();

                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.fromBorderSide(AppTheme.border()),
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
                              color: AppTheme.primary,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Payment Updates',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary,
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
                            title: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              message,
                              style: const TextStyle(fontSize: 12),
                            ),
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

            // Horizontal Filter Tabs
            Padding(
              padding: const EdgeInsets.all(16),
              child: ZelpCategoryTabs(
                items: _filters,
                selectedIndex: _filterIndex,
                onChanged: (value) => setState(() => _filterIndex = value),
              ),
            ),

            // Sessions List Feed
            Expanded(
              child: StreamBuilder<List<SessionModel>>(
                stream: _sessionRepository.upcomingStudentSessions(
                  currentUser.uid,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const AppLoadingIndicator(
                      message: 'Loading sessions...',
                    );
                  }

                  final sessions = snapshot.data ?? [];
                  final filteredSessions = _filterIndex == 0
                      ? sessions
                      : sessions
                            .where(
                              (s) =>
                                  _sessionFilterLabel(s) ==
                                  _filters[_filterIndex],
                            )
                            .toList();

                  if (filteredSessions.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _filterIndex == 0
                              ? 'No sessions scheduled yet.'
                              : 'No ${_filters[_filterIndex]} sessions found.',
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: filteredSessions.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final session = filteredSessions[index];
                      final dayStr = session.dateTime.day.toString();
                      final monthStr = DateFormat(
                        'MMM',
                      ).format(session.dateTime).toUpperCase();
                      final timeStr = DateFormat.jm().format(session.dateTime);
                      final durationStr = '${session.durationMinutes} min';
                      final canJoin = _sessionRepository.canJoinSession(
                        session,
                      );
                      final isPast = session.dateTime.isBefore(DateTime.now());

                      // Determine state buttons
                      String primaryLabel = canJoin ? 'Join Meet' : 'Details';
                      String secondaryLabel = isPast ? 'Rebook' : 'Cancel';

                      if (session.status == 'payment_rejected') {
                        primaryLabel = 'Upload Proof';
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ZelpSessionCard(
                            data: ZelpSessionCardData(
                              tutorName: session.tutorName ?? session.tutorId,
                              subject: session.subject,
                              time: timeStr,
                              duration: durationStr,
                              status: session.status,
                              day: dayStr,
                              month: monthStr,
                              joinLabel: primaryLabel,
                              secondaryLabel: secondaryLabel,
                              enabled: true,
                            ),
                            onPrimaryTap: () {
                              if (session.status == 'payment_rejected') {
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
                                      durationMinutes: session.durationMinutes,
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
                              } else if (canJoin) {
                                _startMeeting(context, session, currentUser);
                              } else {
                                Navigator.of(context).push(
                                  AppTransitions.slideFromRight(
                                    page: SessionDetailsScreen(
                                      sessionId: session.id,
                                    ),
                                  ),
                                );
                              }
                            },
                            onSecondaryTap: () {
                              if (isPast) {
                                _rebookSession(context, session);
                              } else {
                                _confirmCancel(context, session);
                              }
                            },
                          ),
                          if (session.status == 'pending_payment_verification')
                            const Padding(
                              padding: EdgeInsets.only(top: 6, left: 4),
                              child: Text(
                                'Waiting for payment confirmation',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PastSessionsScreen extends StatefulWidget {
  final SessionRepository sessionRepository;
  final TutorsRepository tutorsRepository;

  const PastSessionsScreen({
    super.key,
    required this.sessionRepository,
    required this.tutorsRepository,
  });

  @override
  State<PastSessionsScreen> createState() => _PastSessionsScreenState();
}

class _PastSessionsScreenState extends State<PastSessionsScreen> {
  static const List<String> _tabs = <String>[
    'Completed',
    'Cancelled',
    'Not Refunded',
  ];

  int _selectedIndex = 0;
  bool _cleanupScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _cleanupRefundedSessions(),
    );
  }

  Future<void> _cleanupRefundedSessions() async {
    if (_cleanupScheduled) return;
    _cleanupScheduled = true;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await widget.sessionRepository.cleanupRefundedCancelledSessions(user.uid);
    } catch (_) {
      // Keep the page usable even if cleanup is blocked by permissions.
    }
  }

  bool _isRefundDone(SessionModel session) {
    final status = (session.refundStatus ?? '').trim().toLowerCase();
    return session.refundDone == true ||
        session.refundedAt != null ||
        session.refundProcessedAt != null ||
        status == 'refunded' ||
        status == 'done';
  }

  List<SessionModel> _sessionsForBucket(List<SessionModel> sessions) {
    final filtered = sessions.where((session) {
      final status = session.status.toLowerCase();
      final refundDone = _isRefundDone(session);

      switch (_selectedIndex) {
        case 0:
          return status == 'completed';
        case 1:
          return status == 'cancelled' && refundDone;
        case 2:
          return status == 'cancelled' && !refundDone;
        default:
          return true;
      }
    }).toList();

    filtered.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return filtered;
  }

  Future<void> _rebookSession(
    BuildContext context,
    SessionModel session,
  ) async {
    try {
      final tutor = await widget.tutorsRepository
          .getTutorById(session.tutorId)
          .first;
      if (!context.mounted) return;

      if (tutor == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tutor profile is unavailable right now.'),
          ),
        );
        return;
      }

      Navigator.of(context).push(
        AppTransitions.slideFromRight(
          page: ZelpTutorProfileScreen(tutor: tutor),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open tutor profile: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: const Text('Past Sessions')),
        body: const Center(
          child: Text('Please sign in to view past sessions.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Past Sessions')),
      body: StreamBuilder<List<SessionModel>>(
        stream: widget.sessionRepository.pastSessions(currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingIndicator(
              message: 'Loading past sessions...',
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Failed to load past sessions: ${snapshot.error}'),
              ),
            );
          }

          final sessions = _sessionsForBucket(
            snapshot.data ?? const <SessionModel>[],
          );

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: ZelpCategoryTabs(
                  items: _tabs,
                  selectedIndex: _selectedIndex,
                  onChanged: (value) => setState(() => _selectedIndex = value),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _selectedIndex == 1
                      ? 'Refunded cancelled sessions are removed automatically.'
                      : _selectedIndex == 2
                      ? 'These sessions were cancelled and still need a refund.'
                      : 'Completed sessions are kept here for review and rebooking.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: sessions.isEmpty
                    ? Center(
                        child: Text(
                          _selectedIndex == 0
                              ? 'No completed sessions yet.'
                              : _selectedIndex == 1
                              ? 'No cancelled sessions with refunds found.'
                              : 'No cancelled sessions waiting for refund found.',
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: sessions.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final session = sessions[index];
                          final dayStr = session.dateTime.day.toString();
                          final monthStr = DateFormat(
                            'MMM',
                          ).format(session.dateTime).toUpperCase();
                          final timeStr = DateFormat.jm().format(
                            session.dateTime,
                          );
                          final durationStr = '${session.durationMinutes} min';

                          return ZelpSessionCard(
                            data: ZelpSessionCardData(
                              tutorName: session.tutorName ?? session.tutorId,
                              subject: session.subject,
                              time: timeStr,
                              duration: durationStr,
                              status: session.status,
                              day: dayStr,
                              month: monthStr,
                              joinLabel: 'View Details',
                              secondaryLabel: 'Rebook',
                              enabled: true,
                            ),
                            onPrimaryTap: () {
                              Navigator.of(context).push(
                                AppTransitions.slideFromRight(
                                  page: SessionDetailsScreen(
                                    sessionId: session.id,
                                  ),
                                ),
                              );
                            },
                            onSecondaryTap: () =>
                                _rebookSession(context, session),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
