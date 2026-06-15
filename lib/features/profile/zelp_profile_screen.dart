import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/app_user.dart';
import '../../models/session_model.dart';
import '../../repositories/session_repository.dart';
import '../../services/notification_service.dart';
import '../../services/profile_photo_storage_service.dart';
import '../../services/theme_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_transitions.dart';
import '../../widgets/pressable_scale.dart';
import '../admin/payment_verification_screen.dart';
import '../admin/payout_requests_screen.dart';
import '../admin/dispute_resolution_screen.dart';
import '../booking/student_progress_screen.dart';
import 'student_wallet_screen.dart';
import 'privacy_settings_screen.dart';

class ZelpProfileScreen extends StatefulWidget {
  const ZelpProfileScreen({super.key});

  @override
  State<ZelpProfileScreen> createState() => _ZelpProfileScreenState();
}

class _ZelpProfileScreenState extends State<ZelpProfileScreen> {
  final UserService _userService = UserService();
  final SessionRepository _sessionRepository = SessionRepository();
  bool _signingOut = false;
  bool _isUploadingPhoto = false;
  int _photoRefreshKey = 0;

  Future<void> _showNotificationDiagnostics(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('Diagnostics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading status...'),
          ],
        ),
      ),
    );

    final navigator = Navigator.of(context);
    final status = await NotificationService.instance.getNotificationStatus();

    if (!context.mounted) return;
    navigator.pop(); // Dismiss loading

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Status'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: status.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entry.key}: ',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Expanded(
                      child: Text(
                        '${entry.value}',
                        style: TextStyle(
                          fontSize: 13,
                          color: entry.value == false || entry.value == 'denied'
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadPhoto(String uid) async {
    if (_isUploadingPhoto) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Select Profile Photo',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSourceOption(
                  icon: Icons.photo_library_outlined,
                  label: 'Gallery',
                  source: ImageSource.gallery,
                ),
                _buildSourceOption(
                  icon: Icons.camera_alt_outlined,
                  label: 'Camera',
                  source: ImageSource.camera,
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final pickedFile = await ProfilePhotoStorageService.instance.pickImage(source);
    if (pickedFile == null) return;

    setState(() => _isUploadingPhoto = true);

    try {
      final downloadUrl = await ProfilePhotoStorageService.instance.uploadProfilePhoto(
        image: pickedFile,
        userId: uid,
        pathPrefix: 'users',
      );

      await _userService.updateUserPhotoUrl(uid, downloadUrl);

      if (!mounted) return;
      setState(() => _photoRefreshKey++);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile photo updated successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload photo: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required ImageSource source,
  }) {
    return InkWell(
      onTap: () => Navigator.pop(context, source),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        child: Column(
          children: [
            Icon(icon, size: 36, color: AppTheme.primary),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

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
          key: ValueKey(_photoRefreshKey),
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
                          Stack(
                            children: [
                              Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: appUser?.photoUrl.isNotEmpty == true ? null : AppTheme.buttonGradient,
                                  image: appUser?.photoUrl.isNotEmpty == true
                                      ? DecorationImage(
                                          image: NetworkImage(appUser!.photoUrl),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                  boxShadow: AppTheme.glow(),
                                ),
                                child: _isUploadingPhoto
                                    ? const Center(
                                        child: CircularProgressIndicator(color: Colors.white),
                                      )
                                    : (appUser?.photoUrl.isNotEmpty == true
                                        ? null
                                        : Center(
                                            child: Text(
                                              initials.isNotEmpty ? initials : 'TR',
                                              style: const TextStyle(
                                                color: AppTheme.background,
                                                fontSize: 24,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          )),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: GestureDetector(
                                  onTap: () => _pickAndUploadPhoto(currentUser.uid),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.photo_camera,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
                      _SettingsTile(
                        icon: Icons.payments_outlined,
                        title: 'Payout Requests',
                        onTap: () {
                          Navigator.of(context).push(
                            AppTransitions.slideFromRight(
                              page: const PayoutRequestsScreen(),
                            ),
                          );
                        },
                      ),
                      _SettingsTile(
                        icon: Icons.gavel_outlined,
                        title: 'Dispute Resolution Center',
                        onTap: () {
                          Navigator.of(context).push(
                            AppTransitions.slideFromRight(
                              page: const DisputeResolutionScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Student-specific section
                    if (appUser?.role.toLowerCase() != 'admin') ...[
                      const Text(
                        'Learning',
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      _SettingsTile(
                        icon: Icons.bar_chart_outlined,
                        title: 'My Progress & History',
                        onTap: () {
                          Navigator.of(context).push(
                            AppTransitions.slideFromRight(
                              page: const StudentProgressScreen(),
                            ),
                          );
                        },
                      ),
                      _SettingsTile(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'My Credit Wallet',
                        onTap: () {
                          Navigator.of(context).push(
                            AppTransitions.slideFromRight(
                              page: const StudentWalletScreen(),
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
                      onTap: () => Navigator.of(context).push(
                        AppTransitions.slideFromRight(
                          page: const PrivacySettingsScreen(),
                        ),
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.help_outline,
                      title: 'Help & Support',
                      onTap: () => Navigator.of(context).push(
                        AppTransitions.slideFromRight(
                          page: const HelpSupportScreen(),
                        ),
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.info_outline,
                      title: 'About Zelp',
                      onTap: () => Navigator.of(context).push(
                        AppTransitions.slideFromRight(
                          page: const AboutZelpScreen(),
                        ),
                      ),
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
