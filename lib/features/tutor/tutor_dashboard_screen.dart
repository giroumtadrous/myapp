import 'package:flutter/material.dart';

import '../../repositories/tutor_auth_repository.dart';
import '../../utils/app_transitions.dart';
import '../tutor/other_tutors_tab.dart';
import '../tutor/past_sessions_tab.dart';
import '../tutor/tutor_availability_screen.dart';
import '../tutor/tutor_own_profile_screen.dart';
import '../tutor/upcoming_sessions_tab.dart';

class TutorDashboardScreen extends StatefulWidget {
  final String tutorId;

  const TutorDashboardScreen({required this.tutorId, super.key});

  @override
  State<TutorDashboardScreen> createState() => _TutorDashboardScreenState();
}

class _TutorDashboardScreenState extends State<TutorDashboardScreen> {
  final _tutorAuthRepository = TutorAuthRepository();
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
      backgroundColor: const Color(0xFFF6F6F8),
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF4051B5).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.school,
                color: Color(0xFF4051B5),
              ),
            ),
            const SizedBox(width: 10),
            const Text('Tutor Portal'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.push(
                context,
                AppTransitions.slideFromRight(
                  page: TutorOwnProfileScreen(tutorId: widget.tutorId),
                ),
              );
            },
            tooltip: 'My Profile',
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () {
              Navigator.push(
                context,
                AppTransitions.slideFromRight(
                  page: TutorAvailabilityScreen(tutorId: widget.tutorId),
                ),
              );
            },
            tooltip: 'Edit Availability',
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
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_graph, color: Color(0xFF4051B5)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedTabIndex == 0
                        ? 'Upcoming sessions overview'
                        : _selectedTabIndex == 1
                            ? 'Past sessions history'
                            : 'Tutor network and collaboration',
                    style: const TextStyle(
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
          Expanded(
            child: IndexedStack(
              index: _selectedTabIndex,
              children: [
                UpcomingSessionsTab(tutorId: widget.tutorId),
                PastSessionsTab(tutorId: widget.tutorId),
                OtherTutorsTab(currentTutorId: widget.tutorId),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 70,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFF4051B5).withOpacity(0.14),
        selectedIndex: _selectedTabIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedTabIndex = index);
        },
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Schedule',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: 'Tutors',
          ),
        ],
      ),
    );
  }
}
