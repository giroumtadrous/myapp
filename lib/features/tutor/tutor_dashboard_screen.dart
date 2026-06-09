import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/session_model.dart';
import '../../repositories/session_repository.dart';
import '../../repositories/tutor_auth_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_transitions.dart';
import '../messages/zelp_messages_screen.dart';
import '../tutor/other_tutors_tab.dart';
import '../tutor/past_sessions_tab.dart';
import '../tutor/tutor_availability_screen.dart';
import '../tutor/tutor_own_profile_screen.dart';
import '../tutor/upcoming_sessions_tab.dart';
import '../../widgets/app_loading_indicator.dart';

class TutorDashboardScreen extends StatefulWidget {
  final String tutorId;

  const TutorDashboardScreen({required this.tutorId, super.key});

  @override
  State<TutorDashboardScreen> createState() => _TutorDashboardScreenState();
}

class _TutorDashboardScreenState extends State<TutorDashboardScreen> {
  final _tutorAuthRepository = TutorAuthRepository();
  final _sessionRepository = SessionRepository();
  int _selectedTabIndex = 0;
  bool _signingOut = false;

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
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
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
        backgroundColor: AppTheme.darkSurface,
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
    return ListView(
      key: key,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        const Text(
          "Today's Sessions",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Text(
                    'No sessions today 🎉',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
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
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          session.subject,
                          style: const TextStyle(
                            color: Color(0xFF475569),
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
                              color: Color(0xFF4051B5),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              DateFormat.jm().format(session.dateTime),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF4051B5),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: const [
              Icon(Icons.auto_graph, color: Color(0xFF4051B5)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Upcoming sessions overview',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Text(
            'Use the Sessions tab below to manage upcoming and past sessions.',
            style: TextStyle(
              color: Color(0xFF64748B),
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
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
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
