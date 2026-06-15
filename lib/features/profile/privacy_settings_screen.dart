import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../theme/app_theme.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _allowAnalytics = true;
  bool _allowNotifications = true;
  bool _isDeleting = false;

  Future<void> _deleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete your account and all your data including sessions, payments, and profile. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final uid = user.uid;
      final db = FirebaseFirestore.instance;

      // Delete user Firestore data
      await Future.wait([
        db.collection('users').doc(uid).delete(),
        db.collection('sessions')
            .where('studentId', isEqualTo: uid)
            .get()
            .then((snap) async {
          final batch = db.batch();
          for (final doc in snap.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        }),
        db.collection('notifications')
            .where('userId', isEqualTo: uid)
            .get()
            .then((snap) async {
          final batch = db.batch();
          for (final doc in snap.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        }),
      ]);

      // Delete Firebase Auth account
      await user.delete();

      if (!mounted) return;
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);

      if (e is FirebaseAuthException && e.code == 'requires-recent-login') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please sign out and sign back in before deleting your account.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete account: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Privacy Settings')),
      body: _isDeleting
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Deleting your account...'),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Legal
                _SectionHeader(title: 'Legal'),
                _LinkTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  isDark: isDark,
                  onTap: () => launchUrl(
                    Uri.parse(
                      'https://www.termsfeed.com/live/498ec246-650a-4329-a1d3-c0217639a5ec',
                    ),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                _LinkTile(
                  icon: Icons.description_outlined,
                  title: 'Terms of Service',
                  isDark: isDark,
                  onTap: () => launchUrl(
                    Uri.parse(
                      'https://www.termsfeed.com/live/498ec246-650a-4329-a1d3-c0217639a5ec',
                    ),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                const SizedBox(height: 16),

                // Account
                _SectionHeader(title: 'Account'),
                _LinkTile(
                  icon: Icons.delete_forever_outlined,
                  title: 'Delete Account',
                  textColor: Colors.red,
                  isDark: isDark,
                  onTap: () => _deleteAccount(context),
                ),
                const SizedBox(height: 24),

                // Info note
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.darkSurface
                        : AppTheme.lightSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.fromBorderSide(
                        AppTheme.border(isDark: isDark)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline,
                          size: 16, color: AppTheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Deleting your account will permanently remove all your data from Zelp. This action cannot be reversed.',
                          style: TextStyle(
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.lightTextSecondary,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const _faqs = [
    {
      'q': 'How do I book a session?',
      'a': 'Browse tutors from the home screen, select one you like, choose an available time slot, and complete the payment. Your session will appear in My Sessions once confirmed.',
    },
    {
      'q': 'How do I cancel a session?',
      'a': 'Go to My Sessions, find the session you want to cancel, and tap Cancel. Cancellations made 24 hours before the session receive a full credit refund.',
    },
    {
      'q': 'What is SOS Tutoring?',
      'a': 'SOS Tutoring connects you with an available tutor instantly for emergency help. Simply select your subject and we will match you with a tutor in minutes.',
    },
    {
      'q': 'How do I join my session?',
      'a': 'Once your session is approved, a meeting link will appear in My Sessions. The link is also sent to your email so you can join from your laptop.',
    },
    {
      'q': 'What payment methods are accepted?',
      'a': 'We accept Visa, Mastercard, and InstaPay transfers. For InstaPay, upload a screenshot of your transfer as proof and our team will verify it.',
    },
    {
      'q': 'How do I become a tutor on Zelp?',
      'a': 'Contact us at jeromaged2018@gmail.com with your university, subjects you can teach, and a brief introduction. We will get back to you within 48 hours.',
    },
    {
      'q': 'What happens if my tutor does not show up?',
      'a': 'Contact us immediately at jeromaged2018@gmail.com. We will investigate and issue a full refund if the tutor was at fault.',
    },
    {
      'q': 'How are tutors verified?',
      'a': 'All tutors on Zelp are verified students or graduates from Egyptian universities. We review their academic background before approving their profiles.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Contact card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.fromBorderSide(AppTheme.border(isDark: isDark)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.headset_mic_outlined,
                        color: AppTheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Contact Support',
                      style: TextStyle(
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.lightTextPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'We typically respond within 24 hours.',
                  style: TextStyle(
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                _ContactButton(
                  icon: Icons.email_outlined,
                  label: 'Email Us',
                  subtitle: 'jeromaged2018@gmail.com',
                  isDark: isDark,
                  onTap: () => launchUrl(
                    Uri.parse(
                      'mailto:jeromaged2018@gmail.com?subject=Zelp Support Request',
                    ),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Frequently Asked Questions',
            style: TextStyle(
              color: isDark
                  ? AppTheme.darkTextPrimary
                  : AppTheme.lightTextPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),

          ..._faqs.map((faq) => _FaqTile(
                question: faq['q']!,
                answer: faq['a']!,
                isDark: isDark,
              )),

          const SizedBox(height: 16),

          // Still need help
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: AppTheme.primary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Still need help? Email us at jeromaged2018@gmail.com and we will get back to you as soon as possible.',
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDark;

  const _ContactButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primary, size: 20),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios,
                color: AppTheme.primary, size: 14),
          ],
        ),
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  final String question;
  final String answer;
  final bool isDark;

  const _FaqTile({
    required this.question,
    required this.answer,
    required this.isDark,
  });

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: widget.isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.fromBorderSide(AppTheme.border(isDark: widget.isDark)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          widget.question,
          style: TextStyle(
            color: widget.isDark
                ? AppTheme.darkTextPrimary
                : AppTheme.lightTextPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        trailing: Icon(
          _expanded ? Icons.remove : Icons.add,
          color: AppTheme.primary,
          size: 18,
        ),
        onExpansionChanged: (v) => setState(() => _expanded = v),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              widget.answer,
              style: TextStyle(
                color: widget.isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AboutZelpScreen extends StatefulWidget {
  const AboutZelpScreen({super.key});

  @override
  State<AboutZelpScreen> createState() => _AboutZelpScreenState();
}

class _AboutZelpScreenState extends State<AboutZelpScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _version = '${info.version} (${info.buildNumber})');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('About Zelp')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Logo & tagline
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.fromBorderSide(AppTheme.border(isDark: isDark)),
            ),
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    gradient: AppTheme.buttonGradient,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: AppTheme.glow(),
                  ),
                  child: const Center(
                    child: Text(
                      'Z',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Zelp',
                  style: TextStyle(
                    color: isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.lightTextPrimary,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Learn from those who just got there.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Version $_version',
                  style: TextStyle(
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Mission
          _InfoCard(
            isDark: isDark,
            icon: Icons.lightbulb_outline,
            title: 'Our Mission',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bodyText(
                  'Zelp was built on a simple belief: the best person to help you understand something is someone who recently learned it themselves.',
                  isDark,
                ),
                const SizedBox(height: 10),
                _bodyText(
                  'We connect Egyptian students with peer tutors — people from the same universities, studying the same subjects, who know exactly what you\'re going through. No corporate tutoring centers. No overpriced sessions. Just real students helping each other succeed.',
                  isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Why Zelp
          _InfoCard(
            isDark: isDark,
            icon: Icons.star_outline,
            title: 'Why Zelp?',
            child: Column(
              children: [
                _WhyItem(
                  emoji: '🎯',
                  title: 'Peer-to-Peer Learning',
                  description:
                      'Learn from students who just aced the same course at your university.',
                  isDark: isDark,
                ),
                _WhyItem(
                  emoji: '⚡',
                  title: 'SOS Tutoring',
                  description:
                      'Need help right now? Get matched with an available tutor in minutes.',
                  isDark: isDark,
                ),
                _WhyItem(
                  emoji: '💰',
                  title: 'Affordable Sessions',
                  description:
                      'Fair pricing set by tutors, not by corporations.',
                  isDark: isDark,
                ),
                _WhyItem(
                  emoji: '🇪🇬',
                  title: 'Built for Egypt',
                  description:
                      'Designed specifically for Egyptian students and universities.',
                  isDark: isDark,
                ),
                _WhyItem(
                  emoji: '🆘',
                  title: 'Always Available',
                  description:
                      'With SOS tutoring, help is always just a tap away whenever you need it most.',
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Footer
          const Center(
            child: Text(
              'Made with ❤️ in Egypt',
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              '© 2026 Zelp. All rights reserved.',
              style: TextStyle(
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Text _bodyText(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
        fontSize: 13,
        height: 1.6,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String title;
  final Widget child;

  const _InfoCard({
    required this.isDark,
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.fromBorderSide(AppTheme.border(isDark: isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.lightTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _WhyItem extends StatelessWidget {
  final String emoji;
  final String title;
  final String description;
  final bool isDark;

  const _WhyItem({
    required this.emoji,
    required this.title,
    required this.description,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.lightTextPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isDark;

  const _LegalTile({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.isDark,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.lightTextPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared Widgets ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool isDark;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.fromBorderSide(AppTheme.border(isDark: isDark)),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primary),
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: isDark
                ? AppTheme.darkTextSecondary
                : AppTheme.lightTextSecondary,
            fontSize: 12,
          ),
        ),
        trailing: Switch(value: value, onChanged: onChanged),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? textColor;
  final bool isDark;

  const _LinkTile({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.isDark,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.fromBorderSide(AppTheme.border(isDark: isDark)),
      ),
      child: ListTile(
        leading: Icon(icon, color: textColor ?? AppTheme.primary),
        title: Text(
          title,
          style: TextStyle(
            color: textColor ??
                (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: isDark
              ? AppTheme.darkTextSecondary
              : AppTheme.lightTextSecondary,
        ),
        onTap: onTap,
      ),
    );
  }
}