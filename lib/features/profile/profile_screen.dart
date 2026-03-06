import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myapp/widgets/session_card.dart';

import '../admin/payment_verification_screen.dart';
import '../../models/app_user.dart';
import '../../models/session_model.dart';
import '../../repositories/session_repository.dart';
import '../../services/user_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _userService = UserService();
  final _sessionRepository = SessionRepository();

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: Text('Not signed in')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: FutureBuilder<AppUser?>(
          future: _userService.getUser(currentUser.uid),
          builder: (context, snapshot) {
            final appUser = snapshot.data;
            final name = appUser?.name.isNotEmpty == true
                ? appUser!.name
                : (currentUser.displayName?.isNotEmpty == true
                    ? currentUser.displayName!
                    : currentUser.email ?? 'User');
            final email = appUser?.email.isNotEmpty == true
                ? appUser!.email
                : currentUser.email ?? '';

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProfileContent(
                    name: name,
                    email: email,
                    memberSince: appUser?.createdAt,
                    role: appUser?.role ?? 'student',
                    isLoading:
                        snapshot.connectionState == ConnectionState.waiting,
                  ),
                  const SizedBox(height: 24),
                  _PastSessionsList(
                    sessionRepository: _sessionRepository,
                    studentId: currentUser.uid,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  final String name;
  final String email;
  final DateTime? memberSince;
  final String role;
  final bool isLoading;

  const _ProfileContent({
    required this.name,
    required this.email,
    this.memberSince,
    this.role = 'student',
    this.isLoading = false,
  });

  String get _memberSinceFormatted {
    if (memberSince == null) return '';
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return 'Member since ${months[memberSince!.month - 1]} ${memberSince!.year}';
  }

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    // authStateChanges() in main.dart redirects to LoginScreen
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isLoading)
          const Padding(
            padding: EdgeInsets.only(bottom: 24),
            child: CircularProgressIndicator(),
          )
        else ...[
          CircleAvatar(
            radius: 44,
            backgroundColor:
                Theme.of(context).colorScheme.primary.withOpacity(0.1),
            child: Icon(
              Icons.person,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: textTheme.bodyMedium?.copyWith(
              color: Colors.grey[700],
            ),
          ),
          if (_memberSinceFormatted.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _memberSinceFormatted,
              style: textTheme.bodySmall?.copyWith(
                color: Colors.grey[700],
              ),
            ),
          ],
        ],
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Account',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.school_outlined),
                title: const Text('Institution'),
                subtitle: const Text('Example University'),
                onTap: null,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.language_outlined),
                title: const Text('Preferred language'),
                subtitle: const Text('English'),
                onTap: null,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('Session reminders'),
                subtitle: const Text('Push & email'),
                onTap: null,
              ),
            ],
          ),
        ),
        if (role.toLowerCase() == 'admin') ...[
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Admin',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PaymentVerificationScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.verified_user_outlined),
              label: const Text('Open Payment Verification'),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Danger zone',
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.red[700],
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => _signOut(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red[700],
              side: BorderSide(color: Colors.red[300]!),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Log out'),
          ),
        ),
      ],
    );
  }
}

// ── Past Sessions ─────────────────────────────────────────────────────────────
class _PastSessionsList extends StatelessWidget {
  final SessionRepository sessionRepository;
  final String studentId;

  const _PastSessionsList({
    required this.sessionRepository,
    required this.studentId,
  });

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Past Sessions',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<SessionModel>>(
          stream: sessionRepository.pastSessions(studentId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final sessions = snapshot.data ?? [];
            if (sessions.isEmpty) {
              return Text(
                'No past sessions yet.',
                style: textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              );
            }
            return Column(
              children: sessions.map((s) {
                final dateStr = DateFormat.yMMMd().format(s.dateTime);
                final timeStr = DateFormat.jm().format(s.dateTime);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SessionCard(
                    tutorName: s.tutorName ?? s.tutorId,
                    subject: s.subject,
                    date: dateStr,
                    timeRange: timeStr,
                    statusLabel: s.status,
                    statusColor: _statusColor(s.status),
                    isActive: false,
                    isPast: true,
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
