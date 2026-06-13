import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../repositories/payment_repository.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_transitions.dart';
import '../../widgets/app_loading_indicator.dart';
import '../booking/review_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final PaymentRepository _paymentRepository = PaymentRepository();
  bool _muted = false;
  bool _loadingPreference = true;

  @override
  void initState() {
    super.initState();
    _loadMutePreference();
    _markAllAsRead();
  }

  Future<void> _loadMutePreference() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (!mounted) return;
      setState(() => _loadingPreference = false);
      return;
    }

    final muted = await NotificationService.instance.isMutedForUser(uid);
    if (!mounted) return;
    setState(() {
      _muted = muted;
      _loadingPreference = false;
    });
  }

  Future<void> _toggleMute(bool value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await NotificationService.instance.setMutedForUser(uid: uid, muted: value);
    if (!mounted) return;
    setState(() => _muted = value);
  }

  Future<void> _markAllAsRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final notifications = await FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .get();

    if (notifications.docs.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in notifications.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view notifications.')),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.fromBorderSide(AppTheme.border(isDark: isDark)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.volume_off_outlined,
                  color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF475569),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Mute future alerts',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                    ),
                  ),
                ),
                if (_loadingPreference)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Switch.adaptive(value: _muted, onChanged: _toggleMute),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _paymentRepository.userNotifications(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AppLoadingIndicator(
                    message: 'Loading notifications...',
                  );
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No notifications yet.'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final type = (data['type'] ?? '').toString();
                    final sessionId = (data['sessionId'] ?? '').toString();
                    final title = (data['title'] ?? 'Notification').toString();
                    final message = (data['message'] ?? '').toString();
                    final isRead = data['read'] == true;
                    final createdAt = data['createdAt'];
                    final createdAtDate = createdAt is Timestamp
                        ? createdAt.toDate()
                        : null;

                    return GestureDetector(
                      onTap: () {
                        // Mark as read when tapped
                        if (!isRead) {
                          _paymentRepository.markNotificationRead(doc.id);
                        }
                        
                        if (type == 'review_request' && sessionId.isNotEmpty) {
                          Navigator.of(context).push(
                            AppTransitions.slideFromRight(
                              page: ReviewScreen(sessionId: sessionId),
                            ),
                          );
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isRead
                            ? (isDark ? AppTheme.darkSurface : AppTheme.lightSurface)
                            : (isDark ? AppTheme.primary.withValues(alpha: 0.1) : const Color(0xFFF0F4FF)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.fromBorderSide(
                          isRead
                              ? AppTheme.border(isDark: isDark)
                              : BorderSide(
                                  color: isDark
                                      ? AppTheme.primary.withValues(alpha: 0.35)
                                      : const Color(0xFFCAD5FF),
                                  width: 1.2,
                                ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isRead
                                ? Icons.notifications_none_rounded
                                : Icons.notifications_active_outlined,
                            color: isRead
                                ? (isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B))
                                : AppTheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: isRead
                                        ? (isDark ? AppTheme.darkTextPrimary : const Color(0xFF334155))
                                        : (isDark ? AppTheme.primary : const Color(0xFF1E3A8A)),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  message,
                                  style: TextStyle(
                                    color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF475569),
                                  ),
                                ),
                                if (createdAtDate != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    DateFormat.yMMMd().add_jm().format(createdAtDate),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (!isRead)
                            TextButton(
                              onPressed: () => _paymentRepository.markNotificationRead(doc.id),
                              child: const Text('Mark read'),
                            ),
                        ],
                      ),
                    ));
                  },
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemCount: docs.length,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
