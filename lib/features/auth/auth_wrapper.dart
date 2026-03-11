import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../repositories/tutor_auth_repository.dart';
import '../../utils/app_transitions.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/pressable_scale.dart';
import '../dashboard/main_navigation_screen.dart';
import '../tutor/tutor_dashboard_screen.dart';
import 'login_screen.dart';
import 'tutor_login_screen.dart';

/// Root auth listener that swaps between sign-in and dashboard screens.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final tutorAuthRepository = TutorAuthRepository();

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
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

              return const MainNavigationScreen();
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

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jerome',
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1-on-1 peer tutoring, on demand.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 48),
                  Text(
                    'I am a:',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: PressableScale(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            AppTransitions.slideFromRight(
                              page: const LoginScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.person),
                        label: const Text('Student'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: PressableScale(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            AppTransitions.slideFromRight(
                              page: const TutorLoginScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.school),
                        label: const Text('Tutor'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                      ),
                    ),
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
