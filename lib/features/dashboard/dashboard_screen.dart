import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/session_model.dart';
import '../../models/tutor_model.dart';
import '../../repositories/payment_repository.dart';
import '../../repositories/session_repository.dart';
import '../../repositories/tutors_repository.dart';
import '../../services/jitsi_meet_service.dart';
import '../../services/user_service.dart';
import '../../utils/app_transitions.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/fade_in_stagger.dart';
import '../../widgets/session_card.dart';
import '../../widgets/tutor_card.dart';
import '../booking/session_details_screen.dart';
import '../booking/tutor_booking_screen.dart';
import '../explore/explore_screen.dart';
import '../notifications/notifications_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _userService = UserService();
  final _tutorsRepository = TutorsRepository();
  final _sessionRepository = SessionRepository();
  final _paymentRepository = PaymentRepository();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 120,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Header(
                    userService: _userService,
                    paymentRepository: _paymentRepository,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Top Rated Tutors',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            AppTransitions.slideFromRight(
                              page: const ExploreScreen(),
                            ),
                          );
                        },
                        child: const Text('Explore'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<List<Tutor>>(
                    stream: _tutorsRepository.getTutors(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const _TutorsLoadingState();
                      }

                      if (snapshot.hasError) {
                        return _TutorsErrorState(
                          message:
                              snapshot.error?.toString() ??
                              'Something went wrong',
                        );
                      }

                      final tutors = [...(snapshot.data ?? [])]
                        ..sort((a, b) => b.rating.compareTo(a.rating));
                      final topTutors = tutors.take(3).toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (topTutors.isEmpty)
                            const _TutorsEmptyState()
                          else
                            Column(
                              children: List.generate(topTutors.length, (
                                index,
                              ) {
                                final tutor = topTutors[index];

                                return FadeInStagger(
                                  index: index,
                                  child: TutorCard(
                                    tutor: tutor,
                                    onTap: () {
                                      Navigator.of(context).push(
                                        AppTransitions.slideFromRight(
                                          page: TutorBookingScreen(tutor: tutor),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              }),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Upcoming Sessions',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _UpcomingSessionsList(sessionRepository: _sessionRepository),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UpcomingSessionsList extends StatelessWidget {
  final SessionRepository sessionRepository;

  const _UpcomingSessionsList({required this.sessionRepository});

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

  Color _statusColor(String status) {
    switch (status) {
      case 'booked':
      case 'confirmed':
        return Colors.green[600]!;
      case 'pending_payment_verification':
        return Colors.orange[700]!;
      case 'payment_rejected':
        return Colors.red[700]!;
      default:
        return Colors.blueGrey;
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
      await sessionRepository.cancelSession(session.id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Session cancelled.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Text('Sign in to see your sessions.');
    }

    return StreamBuilder<List<SessionModel>>(
      stream: sessionRepository.upcomingSessions(currentUser.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingIndicator(
            message: 'Loading upcoming sessions...',
          );
        }
        final sessions = snapshot.data ?? [];
        for (final s in sessions) {
          debugPrint(
            '[Dashboard][student] session=${s.id} status=${s.status} '
            'duration=${s.durationMinutes} slotCount=${s.slotCount} '
            'dateTime=${s.dateTime.toIso8601String()}',
          );
        }
        if (sessions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No upcoming sessions yet. Book a tutor to get started.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
          );
        }
        return Column(
          children: sessions.map((s) {
            final dateStr = DateFormat.yMMMd().format(s.dateTime);
            final timeStr = DateFormat.jm().format(s.dateTime);
            final canJoin = sessionRepository.canJoinSession(s);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SessionCard(
                tutorName: s.tutorName ?? s.tutorId,
                subject: s.subject,
                date: dateStr,
                sessionDateTime: s.dateTime,
                timeRange: timeStr,
                statusLabel: s.status,
                statusColor: _statusColor(s.status),
                isActive: false,
                durationMinutes: s.durationMinutes,
                onTap: () {
                  Navigator.of(context).push(
                    AppTransitions.slideFromRight(
                      page: SessionDetailsScreen(sessionId: s.id),
                    ),
                  );
                },
                onJoinMeet: canJoin
                    ? () => _startMeeting(context, s, currentUser)
                    : null,
                onCancel: () => _confirmCancel(context, s),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _TutorsLoadingState extends StatelessWidget {
  const _TutorsLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: AppLoadingIndicator(message: 'Fetching tutors...'),
      ),
    );
  }
}

class _TutorsErrorState extends StatelessWidget {
  final String message;

  const _TutorsErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Something went wrong',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorsEmptyState extends StatelessWidget {
  const _TutorsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No tutors available',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Check back later or explore other pages.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final UserService userService;
  final PaymentRepository paymentRepository;

  const _Header({required this.userService, required this.paymentRepository});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final currentUser = FirebaseAuth.instance.currentUser;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            child: Icon(Icons.person, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FutureBuilder(
              future: currentUser != null
                  ? userService.getUser(currentUser.uid)
                  : null,
              builder: (context, snapshot) {
                final name = snapshot.data?.name.isNotEmpty == true
                    ? snapshot.data!.name
                    : (currentUser?.displayName?.isNotEmpty == true
                          ? currentUser!.displayName!
                          : currentUser?.email ?? 'User');
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome Back,',
                      style: textTheme.bodySmall?.copyWith(
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          _NotificationBell(paymentRepository: paymentRepository),
        ],
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  final PaymentRepository paymentRepository;

  const _NotificationBell({required this.paymentRepository});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return _NotificationBellButton(
        unreadCount: 0,
        onPressed: () {
          Navigator.of(context).push(
            AppTransitions.slideFromRight(page: const NotificationsScreen()),
          );
        },
      );
    }

    return StreamBuilder(
      stream: paymentRepository.userNotifications(user.uid),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final unreadCount = docs.where((doc) => doc.data()['read'] != true).length;

        return _NotificationBellButton(
          unreadCount: unreadCount,
          onPressed: () {
            Navigator.of(context).push(
              AppTransitions.slideFromRight(page: const NotificationsScreen()),
            );
          },
        );
      },
    );
  }
}

class _NotificationBellButton extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onPressed;

  const _NotificationBellButton({
    required this.unreadCount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ),
        if (unreadCount > 0)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(99),
              ),
              constraints: const BoxConstraints(minWidth: 18),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
