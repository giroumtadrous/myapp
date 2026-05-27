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
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  bool _loadingGoogle = false;
  bool _loadingApple = false;

  bool get _isAppleAvailable =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> _handlePostSignIn(UserCredential? credential) async {
    if (credential == null || credential.user == null) return;

    final user = credential.user!;

    try {
      final complete = await _authService.isProfileComplete(user.uid);

      if (!mounted) return;

      if (!complete) {
        Navigator.of(context).pushReplacement(
          AppTransitions.slideFromRight(page: const CompleteProfileScreen()),
        );
        return;
      }

      await _userService.syncFcmToken(user.uid);
      await NotificationService.instance.initialize();

      if (!mounted) return;
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
    final textTheme = Theme.of(context).textTheme;
    final width = MediaQuery.of(context).size.width;
    final maxCardWidth = width > 600 ? 460.0 : double.infinity;

    return Scaffold(
      appBar: AppBar(title: const Text('Student sign in')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxCardWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Student portal',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in with Google, Apple, or email.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: PressableScale(
                      child: OutlinedButton.icon(
                        onPressed:
                            _loadingGoogle || _loadingApple ? null : _signInWithGoogle,
                        icon: _loadingGoogle
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.g_mobiledata, size: 26),
                        label: const Text('Continue with Google'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ),
                  ),
                  if (_isAppleAvailable) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: PressableScale(
                        child: OutlinedButton.icon(
                          onPressed:
                              _loadingGoogle || _loadingApple ? null : _signInWithApple,
                          icon: _loadingApple
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.apple, size: 20),
                          label: const Text('Continue with Apple'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: const [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or'),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: PressableScale(
                      child: ElevatedButton.icon(
                        onPressed: _loadingGoogle || _loadingApple
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  AppTransitions.slideFromRight(
                                    page: const LoginScreen(),
                                  ),
                                );
                              },
                        icon: const Icon(Icons.mail_outline_rounded),
                        label: const Text('Sign in with email'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
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
