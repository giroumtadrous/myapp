import 'package:flutter/material.dart';

import '../tutor/upcoming_sessions_tab.dart';
import '../tutor/past_sessions_tab.dart';
import '../tutor/other_tutors_tab.dart';
import '../../repositories/tutor_auth_repository.dart';

class TutorDashboardScreen extends StatefulWidget {
  final String tutorId;

  const TutorDashboardScreen({
    required this.tutorId,
    super.key,
  });

  @override
  State<TutorDashboardScreen> createState() => _TutorDashboardScreenState();
}

class _TutorDashboardScreenState extends State<TutorDashboardScreen> {
  final _tutorAuthRepository = TutorAuthRepository();
  int _selectedTabIndex = 0;

  Future<void> _signOut() async {
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
      await _tutorAuthRepository.signOut();
      // Navigation handled by _AuthGate in main.dart
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tutor Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedTabIndex,
        children: [
          UpcomingSessionsTab(tutorId: widget.tutorId),
          PastSessionsTab(tutorId: widget.tutorId),
          OtherTutorsTab(currentTutorId: widget.tutorId),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTabIndex,
        onTap: (index) {
          setState(() => _selectedTabIndex = index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule),
            label: 'Upcoming',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Past',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Tutors',
          ),
        ],
      ),
    );
  }
}
