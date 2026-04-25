import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/user_service.dart';
import '../../utils/app_transitions.dart';
import '../../widgets/pressable_scale.dart';
import 'complete_profile_screen.dart';
import 'login_screen.dart';

class SocialLoginScreen extends StatefulWidget {
  const SocialLoginScreen({super.key});

  @override
  State<SocialLoginScreen> createState() => _SocialLoginScreenState();
}

class _SocialLoginScreenState extends State<SocialLoginScreen> {
  final _authService = AuthService();
  final _userService = UserService();
  bool _loadingGoogle = false;
  bool _loadingApple = false;

  bool get _isAppleAvailable => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> _handlePostSignIn(UserCredential? credential) async {
    if (credential == null || credential.user == null) return;

    final user = credential.user!;
    
    try {
      // Check if profile exists and is complete
      final complete = await _authService.isProfileComplete(user.uid);

      if (!mounted) return;

      if (!complete) {
        // Redirect to profile completion screen
        Navigator.of(context).pushReplacement(
          AppTransitions.slideFromRight(page: const CompleteProfileScreen()),
        );
        return;
      }

      // Profile is complete, sync FCM token AFTER authentication
      await _userService.syncFcmToken(user.uid);
      await NotificationService.instance.initialize();

      if (!mounted) return;

      // Return to root auth wrapper so authStateChanges can render dashboard.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to complete sign-in: $e')),
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loadingGoogle = true);
    try {
      final credential = await _authService.signInWithGoogle();
      await _handlePostSignIn(credential);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google sign-in failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingGoogle = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _loadingApple = true);
    try {
      final credential = await _authService.signInWithApple();
      await _handlePostSignIn(credential);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Apple sign-in failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingApple = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.school, size: 46, color: Color(0xFF4051B5)),
                      const SizedBox(height: 8),
                      Text(
                        'TutorLink',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 24),
                      PressableScale(
                        child: ElevatedButton.icon(
                          onPressed: _loadingGoogle || _loadingApple ? null : _signInWithGoogle,
                          icon: _loadingGoogle
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.g_mobiledata, size: 26),
                          label: const Text('Continue with Google'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            backgroundColor: const Color(0xFF4051B5),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      if (_isAppleAvailable) ...[
                        const SizedBox(height: 12),
                        PressableScale(
                          child: OutlinedButton.icon(
                            onPressed: _loadingGoogle || _loadingApple ? null : _signInWithApple,
                            icon: _loadingApple
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.apple),
                            label: const Text('Continue with Apple'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        children: const [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text('or'),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loadingGoogle || _loadingApple
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  AppTransitions.slideFromRight(page: const LoginScreen()),
                                );
                              },
                        child: const Text('Sign in with Email'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
