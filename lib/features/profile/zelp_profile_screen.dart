import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/session_model.dart';
import '../../repositories/session_repository.dart';
import '../../services/theme_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_transitions.dart';
import '../../widgets/pressable_scale.dart';
import '../admin/payment_verification_screen.dart';

class ZelpProfileScreen extends StatefulWidget {
  const ZelpProfileScreen({super.key});

  @override
  State<ZelpProfileScreen> createState() => _ZelpProfileScreenState();
}

class _ZelpProfileScreenState extends State<ZelpProfileScreen> {
  final UserService _userService = UserService();
  final SessionRepository _sessionRepository = SessionRepository();
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
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
      } finally {
        if (mounted) {
          setState(() => _signingOut = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: Text('Please sign in to view profile.')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: FutureBuilder<AppUser?>(
          future: _userService.getUser(currentUser.uid),
          builder: (context, userSnapshot) {
            final appUser = userSnapshot.data;
            final name = appUser?.name.isNotEmpty == true
                ? appUser!.name
                : (currentUser.displayName?.isNotEmpty == true
                    ? currentUser.displayName!
                    : currentUser.email?.split('@').first ?? 'User');
            final initials = name.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join();

            return StreamBuilder<List<SessionModel>>(
              stream: _sessionRepository.pastSessions(currentUser.uid),
              builder: (context, sessionSnapshot) {
                final completedCount = sessionSnapshot.data?.where((s) => s.status.toLowerCase() == 'completed').length ?? 0;
                final totalCount = sessionSnapshot.data?.length ?? 0;

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Profile Header card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.fromBorderSide(AppTheme.border()),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppTheme.buttonGradient,
                              boxShadow: AppTheme.glow(),
                            ),
                            child: Center(
                              child: Text(
                                initials.isNotEmpty ? initials : 'TR',
                                style: const TextStyle(
                                  color: AppTheme.background,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            name,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            appUser?.role.toUpperCase() ?? 'STUDENT',
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          if (appUser?.universityOrHighSchool.isNotEmpty == true) ...[
                            const SizedBox(height: 4),
                            Text(
                              appUser!.universityOrHighSchool,
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Dynamic Stats cards Row
                    Row(
                      children: [
                        Expanded(child: _StatCard(value: '$totalCount', label: 'Sessions')),
                        const SizedBox(width: 10),
                        Expanded(child: _StatCard(value: '$completedCount', label: 'Completed')),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            value: appUser?.role.toLowerCase() == 'admin' ? 'Admin' : 'Active',
                            label: 'Status',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Admin Panel routing (if admin user)
                    if (appUser?.role.toLowerCase() == 'admin') ...[
                      const Text(
                        'Administrative Tools',
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      _SettingsTile(
                        icon: Icons.verified_user_outlined,
                        title: 'Payment Verification Manager',
                        onTap: () {
                          Navigator.of(context).push(
                            AppTransitions.slideFromRight(
                              page: const PaymentVerificationScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    const Text(
                      'Settings',
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),

                    // Dark Mode control tile
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.fromBorderSide(AppTheme.border()),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.brightness_4_outlined, color: AppTheme.primary),
                        title: const Text('Dark Mode', style: TextStyle(color: AppTheme.textPrimary)),
                        trailing: Switch(
                          value: ThemeService().isDarkMode,
                          onChanged: (value) {
                            ThemeService().setDarkMode(value);
                            setState(() {});
                          },
                        ),
                      ),
                    ),

                    _SettingsTile(
                      icon: Icons.lock_outline,
                      title: 'Privacy Settings',
                      onTap: () {},
                    ),
                    _SettingsTile(
                      icon: Icons.help_outline,
                      title: 'Help & Support',
                      onTap: () {},
                    ),
                    _SettingsTile(
                      icon: Icons.info_outline,
                      title: 'About Zelp',
                      onTap: () {},
                    ),
                    const SizedBox(height: 18),

                    // Sign Out button
                    PressableScale(
                      onTap: _signOut,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.fromBorderSide(AppTheme.border()),
                        ),
                        child: Center(
                          child: _signingOut
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text(
                                  'Sign Out',
                                  style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800),
                                ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.fromBorderSide(AppTheme.border()),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.fromBorderSide(AppTheme.border()),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primary),
        title: Text(title, style: const TextStyle(color: AppTheme.textPrimary)),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
        onTap: onTap,
      ),
    );
  }
}
