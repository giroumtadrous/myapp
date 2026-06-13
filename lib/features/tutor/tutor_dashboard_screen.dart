import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/session_model.dart';
import '../../repositories/session_repository.dart';
import '../../repositories/tutor_auth_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_transitions.dart';
import '../../services/messaging_service.dart';
import '../../repositories/payment_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../messages/zelp_messages_screen.dart';
import '../notifications/notifications_screen.dart';
import '../tutor/other_tutors_tab.dart';
import '../tutor/past_sessions_tab.dart';
import '../tutor/tutor_availability_screen.dart';
import '../tutor/tutor_earnings_screen.dart';
import '../tutor/tutor_own_profile_screen.dart';
import '../tutor/upcoming_sessions_tab.dart';
import '../../widgets/app_loading_indicator.dart';
import 'sos_accept_dialog.dart';

class TutorDashboardScreen extends StatefulWidget {
  final String tutorId;

  const TutorDashboardScreen({required this.tutorId, super.key});

  @override
  State<TutorDashboardScreen> createState() => _TutorDashboardScreenState();
}

class _TutorDashboardScreenState extends State<TutorDashboardScreen> {
  final _tutorAuthRepository = TutorAuthRepository();
  final _sessionRepository = SessionRepository();
  final _paymentRepository = PaymentRepository();
  int _selectedTabIndex = 0;
  bool _signingOut = false;
  StreamSubscription? _sosNotificationSubscription;

  @override
  void initState() {
    super.initState();
    _listenForSosRequests();
  }

  @override
  void dispose() {
    _sosNotificationSubscription?.cancel();
    super.dispose();
  }

  void _listenForSosRequests() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _sosNotificationSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: currentUser.uid)
        .where('type', isEqualTo: 'sos_request')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;
          final subject = (data['subject'] ?? 'a subject').toString();
          final sosRequestId = (data['sosRequestId'] ?? '').toString();

          if (sosRequestId.isNotEmpty) {
            // Mark notification as read so we don't pop it up again
            change.doc.reference.update({'read': true});

            // Show the modal accept sheet
            SosAcceptDialog.show(
              context: context,
              subject: subject,
              sosRequestId: sosRequestId,
            );
          }
        }
      }
    });
  }

  Future<void> _signOut() async {
    if (_signingOut) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _signingOut = true);
      try {
        await _tutorAuthRepository.signOut();
        // Navigation is handled by AuthWrapper.
      } finally {
        if (mounted) {
          setState(() => _signingOut = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('tutors').doc(widget.tutorId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final tutorData = snapshot.data?.data() ?? <String, dynamic>{};
        final isSuspended = tutorData['isSuspended'] == true;
        final strikeCount = (tutorData['strikeCount'] as num?)?.toInt() ?? 0;

        if (isSuspended) {
          return Scaffold(
            backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.block_flipped,
                      color: Colors.red,
                      size: 88,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Account Suspended',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Colors.red,
                            fontWeight: FontWeight.w800,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your tutor account has been suspended due to receiving $strikeCount strikes from session cancellations or no-shows.\n\nPlease contact support to appeal or resolve this issue.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                            height: 1.5,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Support email/action or help
                        },
                        icon: const Icon(Icons.mail_outline),
                        label: const Text('Contact Support'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _signOut,
                        icon: const Icon(Icons.logout),
                        label: const Text('Log Out'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
          appBar: AppBar(
            backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
            titleSpacing: 16,
            title: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.school,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                const Text('Tutor Portal'),
              ],
            ),
            actions: [
              if (currentUser != null)
                _TutorNotificationBell(paymentRepository: _paymentRepository, currentUser: currentUser),
              _UnreadChatBadge(tutorId: widget.tutorId),
              IconButton(
                icon: _signingOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout),
                onPressed: _signingOut ? null : _signOut,
                tooltip: 'Sign out',
              ),
            ],
          ),
          body: Column(
            children: [
              if (strikeCount > 0 && _selectedTabIndex == 0)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Strike Warning: You currently have $strikeCount/3 strikes. At 3 strikes, your account will be suspended immediately.',
                          style: TextStyle(
                            color: Colors.amber.shade900,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _buildTabBody(),
                ),
              ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            height: 70,
            backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
            indicatorColor: AppTheme.primary.withValues(alpha: 0.16),
            selectedIndex: _selectedTabIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedTabIndex = index);
            },
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.event_note_outlined),
                selectedIcon: Icon(Icons.event_note),
                label: 'Sessions',
              ),
              NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet),
                label: 'Earnings',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month),
                label: 'Availability',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabBody() {
    switch (_selectedTabIndex) {
      case 0:
        return _TutorHomeTab(
          key: const ValueKey('tutor-home-tab'),
          tutorId: widget.tutorId,
          sessionRepository: _sessionRepository,
        );
      case 1:
        return _TutorSessionsTabView(
          key: const ValueKey('tutor-sessions-tab'),
          tutorId: widget.tutorId,
        );
      case 2:
        return TutorEarningsScreen(
          key: const ValueKey('tutor-earnings-tab'),
          tutorId: widget.tutorId,
        );
      case 3:
        return TutorAvailabilityScreen(
          key: const ValueKey('tutor-availability-tab'),
          tutorId: widget.tutorId,
        );
      default:
        return TutorOwnProfileScreen(
          key: const ValueKey('tutor-profile-tab'),
          tutorId: widget.tutorId,
        );
    }
  }
}

class _UnreadChatBadge extends StatelessWidget {
  final String tutorId;

  const _UnreadChatBadge({required this.tutorId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChatRoom>>(
      stream: MessagingService.instance.getChatRoomsStream(tutorId),
      builder: (context, snapshot) {
        int unreadCount = 0;
        if (snapshot.hasData) {
          for (final room in snapshot.data!) {
            unreadCount += room.unreadCounts[tutorId] ?? 0;
          }
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              onPressed: () {
                Navigator.of(context).push(
                  AppTransitions.slideFromRight(
                    page: const ZelpMessagesScreen(),
                  ),
                );
              },
              tooltip: 'Inbox',
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TutorNotificationBell extends StatelessWidget {
  final PaymentRepository paymentRepository;
  final User currentUser;

  const _TutorNotificationBell({required this.paymentRepository, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: paymentRepository.userNotifications(currentUser.uid),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final unreadCount = docs.where((doc) => doc.data()['read'] != true).length;

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded),
              onPressed: () {
                Navigator.of(context).push(
                  AppTransitions.slideFromRight(page: const NotificationsScreen()),
                );
              },
              tooltip: 'Notifications',
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TutorHomeTab extends StatelessWidget {
  final String tutorId;
  final SessionRepository sessionRepository;

  const _TutorHomeTab({
    super.key,
    required this.tutorId,
    required this.sessionRepository,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      key: key,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        Text(
          "Today's Sessions",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 138,
          child: StreamBuilder<List<SessionModel>>(
            stream: sessionRepository.tutorSessionsOnDate(tutorId, DateTime.now()),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const AppLoadingIndicator(message: 'Loading today\'s sessions...');
              }

              final sessions = snapshot.data ?? [];
              if (sessions.isEmpty) {
                return Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.fromBorderSide(AppTheme.border(isDark: isDark)),
                  ),
                  child: Text(
                    'No sessions today 🎉',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                );
              }

              return ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: sessions.length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final session = sessions[index];
                  return Container(
                    width: 230,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.fromBorderSide(AppTheme.border(isDark: isDark)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.studentName ?? 'Student',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          session.subject,
                          style: TextStyle(
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule,
                              size: 16,
                              color: AppTheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              DateFormat.jm().format(session.dateTime),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.fromBorderSide(AppTheme.border(isDark: isDark)),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_graph, color: AppTheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Upcoming sessions overview',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.fromBorderSide(AppTheme.border(isDark: isDark)),
          ),
          child: Text(
            'Use the Sessions tab below to manage upcoming and past sessions.',
            style: TextStyle(
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _TutorSessionsTabView extends StatelessWidget {
  final String tutorId;

  const _TutorSessionsTabView({super.key, required this.tutorId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            unselectedLabelColor: isDark
                ? AppTheme.darkTextSecondary
                : AppTheme.lightTextSecondary,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'Upcoming'),
              Tab(text: 'Past'),
              Tab(text: 'Tutors'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                UpcomingSessionsTab(tutorId: tutorId),
                PastSessionsTab(tutorId: tutorId),
                OtherTutorsTab(currentTutorId: tutorId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
