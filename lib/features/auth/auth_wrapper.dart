import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../repositories/tutor_auth_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_transitions.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/notification_auth_sync.dart';
import '../../widgets/pressable_scale.dart';
import '../dashboard/main_navigation_screen.dart';
import '../tutor/tutor_dashboard_screen.dart';
import 'complete_profile_screen.dart';
import 'social_login_screen.dart';
import 'tutor_login_screen.dart';
import 'verify_email_screen.dart';

/// Root auth listener that swaps between sign-in and dashboard screens.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final tutorAuthRepository = TutorAuthRepository();
    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: AppLoadingIndicator(message: 'Checking session...'),
          );
        }

        Widget child;
        if (!snapshot.hasData) {
          child = const SignInPage();
        } else {
          final user = snapshot.data!;
          child = StreamBuilder<String?>(
            stream: tutorAuthRepository.watchTutorIdFromAuthUid(user.uid),
            builder: (context, tutorSnapshot) {
              if (tutorSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: AppLoadingIndicator(message: 'Preparing dashboard...'),
                );
              }

              if (tutorSnapshot.data != null) {
                return TutorDashboardScreen(tutorId: tutorSnapshot.data!);
              }

              if (!authService.isSocialProviderUser(user)) {
                if (!user.emailVerified) {
                  return const VerifyEmailScreen();
                }
                return const NotificationAuthSync(
                  child: MainNavigationScreen(),
                );
              }

              return StreamBuilder<bool>(
                stream: authService.watchProfileComplete(user.uid),
                builder: (context, profileSnapshot) {
                  if (profileSnapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: AppLoadingIndicator(message: 'Checking profile...'),
                    );
                  }

                  final isComplete = profileSnapshot.data ?? false;
                  if (!isComplete) {
                    return const CompleteProfileScreen();
                  }

                  return const NotificationAuthSync(
                    child: MainNavigationScreen(),
                  );
                },
              );
            },
          );
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: KeyedSubtree(
            key: ValueKey(
              '${child.runtimeType}-${snapshot.data?.uid ?? 'guest'}',
            ),
            child: child,
          ),
        );
      },
    );
  }
}

class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(title: const Text('Choose account type')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width > 600 ? 460 : 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome to Zelp',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pick how you want to continue.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 24),
                  RoleCard(
                    title: 'Student Portal',
                    description: 'Find tutors and book sessions.',
                    icon: Icons.person_rounded,
                    themeColor: const Color(0xFF4051B5),
                    onTap: () {
                      Navigator.of(context).push(
                        AppTransitions.slideFromRight(
                          page: const SocialLoginScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  RoleCard(
                    title: 'Tutor Workspace',
                    description: 'Manage sessions and availability.',
                    icon: Icons.school_rounded,
                    themeColor: AppTheme.primary,
                    onTap: () {
                      Navigator.of(context).push(
                        AppTransitions.slideFromRight(
                          page: const TutorLoginScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RoleCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color themeColor;
  final VoidCallback onTap;

  const RoleCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.themeColor,
    required this.onTap,
  });

  @override
  State<RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<RoleCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isHovered ? widget.themeColor : const Color(0xFFE2E8F0),
              width: _isHovered ? 2.0 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? widget.themeColor.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: _isHovered ? 16 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: widget.themeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.icon,
                        color: widget.themeColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.description,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 18, color: widget.themeColor),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
