import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/tutor_model.dart';
import '../../repositories/payment_repository.dart';
import '../../repositories/tutors_repository.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_transitions.dart';
import '../../widgets/pressable_scale.dart';
import '../../widgets/zelp_ui_components.dart';
import '../booking/zelp_tutor_profile_screen.dart';
import '../notifications/notifications_screen.dart';

class ZelpHomeScreen extends StatefulWidget {
  const ZelpHomeScreen({super.key});

  @override
  State<ZelpHomeScreen> createState() => _ZelpHomeScreenState();
}

class _ZelpHomeScreenState extends State<ZelpHomeScreen> {
  final UserService _userService = UserService();
  final TutorsRepository _tutorsRepository = TutorsRepository();
  final PaymentRepository _paymentRepository = PaymentRepository();

  int _categoryIndex = 0;
  final List<String> _categories = const ['Math', 'Physics', 'Writing', 'Coding'];

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to continue.')),
      );
    }
    final currentUserProfileFuture = _userService.getUser(currentUser.uid);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Navigation Row
              Row(
                children: [
                  _HeaderIconButton(icon: Icons.menu, onTap: () {}),
                  const Spacer(),
                  const Text(
                    'Zelp',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  // Notification bell next to profile
                  _NotificationBell(paymentRepository: _paymentRepository, currentUser: currentUser),
                  const SizedBox(width: 8),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      shape: BoxShape.circle,
                      border: Border.fromBorderSide(AppTheme.border(width: 1.2)),
                    ),
                    child: const Icon(Icons.person_outline, color: AppTheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Welcome greeting
              FutureBuilder<AppUser?>(
                future: currentUserProfileFuture,
                builder: (context, snapshot) {
                  final name = snapshot.data?.name.isNotEmpty == true
                      ? snapshot.data!.name
                      : (currentUser.displayName?.isNotEmpty == true
                          ? currentUser.displayName!
                          : currentUser.email?.split('@').first ?? 'User');
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good day, $name',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (snapshot.data?.universityOrHighSchool.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          snapshot.data!.universityOrHighSchool,
                          style: const TextStyle(
                            color: Color(0xFF0F766E),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 6),
              const Text(
                'Find a tutor, continue learning, and book a session in seconds.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 16),
              
              const ZelpSearchBar(hintText: 'Find tutors or subjects'),
              const SizedBox(height: 16),
              
              ZelpCategoryTabs(
                items: _categories,
                selectedIndex: _categoryIndex,
                onChanged: (value) => setState(() => _categoryIndex = value),
              ),
              const SizedBox(height: 20),

              // Recommended Tutors Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FutureBuilder<AppUser?>(
                    future: currentUserProfileFuture,
                    builder: (context, snapshot) {
                      final institutionRaw =
                          snapshot.data?.universityOrHighSchool.isNotEmpty == true
                              ? snapshot.data!.universityOrHighSchool
                              : snapshot.data?.institution ?? '';
                      final title = institutionRaw.trim().isNotEmpty
                          ? 'Tutors from ${institutionRaw.trim()}'
                          : 'Tutors from your university';

                      return Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    },
                  ),
                  TextButton(onPressed: () {}, child: const Text('View all')),
                ],
              ),
              const SizedBox(height: 10),
              
              // Dynamic Tutors Stream List
              SizedBox(
                height: 260,
                child: FutureBuilder<AppUser?>(
                  future: currentUserProfileFuture,
                  builder: (context, userSnapshot) {
                    if (userSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final institutionRaw =
                        userSnapshot.data?.universityOrHighSchool.isNotEmpty == true
                            ? userSnapshot.data!.universityOrHighSchool
                            : userSnapshot.data?.institution ?? '';
                    final studentInstitution = institutionRaw.trim().toLowerCase();

                    if (studentInstitution.isEmpty) {
                      return const Center(
                        child: Text(
                          'Add your university in profile to view matching tutors.',
                          style: TextStyle(color: AppTheme.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    return StreamBuilder<List<Tutor>>(
                      stream: _tutorsRepository.getTutors(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Center(
                            child: Text(
                              'No tutors available at the moment.',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          );
                        }

                        final tutors = snapshot.data!
                            .where(
                              (tutor) =>
                                  tutor.university.trim().toLowerCase() == studentInstitution,
                            )
                            .toList()
                          ..sort((a, b) => b.rating.compareTo(a.rating));

                        if (tutors.isEmpty) {
                          return const Center(
                            child: Text(
                              'No tutors from your university are available right now.',
                              style: TextStyle(color: AppTheme.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }

                        final topTutors = tutors.take(5).toList();

                        return ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: topTutors.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final tutor = topTutors[index];
                            final names = tutor.name.split(' ');
                            final initials = names.map((n) => n.isNotEmpty ? n[0] : '').take(2).join();

                            return ZelpTutorCard(
                              data: ZelpTutorCardData(
                                photoLabel: initials.isNotEmpty ? initials : 'TR',
                                name: tutor.name,
                                subject: tutor.subjects.isNotEmpty ? tutor.subjects.first : 'Tutor',
                                rating: tutor.rating.toStringAsFixed(1),
                                description: tutor.bio,
                                price: '\$${tutor.hourlyRate.toStringAsFixed(0)}/hr',
                                availability: 'Available today',
                              ),
                              onTap: () {
                                Navigator.of(context).push(
                                  AppTransitions.slideFromRight(
                                    page: ZelpTutorProfileScreen(tutor: tutor),
                                  ),
                                );
                              },
                            );
                          },
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

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.fromBorderSide(AppTheme.border()),
        ),
        child: Icon(icon, color: AppTheme.primary),
      ),
    );
  }
}
/*
class _ContinueLearningCard extends StatelessWidget {
  const _ContinueLearningCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.fromBorderSide(AppTheme.border()),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Continue Learning',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Calculus II: Integration by Parts',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your next lesson is ready. Pick up right where you left off with a focused 25 minute session.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  const ZelpPrimaryButton(label: 'Resume Learning', onTap: null, icon: Icons.play_arrow_rounded),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.fromBorderSide(AppTheme.border()),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: AppTheme.primary, size: 38),
            ),
          ],
        ),
      ),
    );
  }
}
*/
class _NotificationBell extends StatelessWidget {
  final PaymentRepository paymentRepository;
  final User currentUser;

  const _NotificationBell({required this.paymentRepository, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: paymentRepository.userNotifications(currentUser.uid),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final unreadCount = docs.where((doc) => doc.data()['read'] != true).length;

        return PressableScale(
          onTap: () {
            Navigator.of(context).push(
              AppTransitions.slideFromRight(page: const NotificationsScreen()),
            );
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.fromBorderSide(AppTheme.border()),
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: AppTheme.primary,
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    constraints: const BoxConstraints(minWidth: 16),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
