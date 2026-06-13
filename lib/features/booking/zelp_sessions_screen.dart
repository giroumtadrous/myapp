import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/session_model.dart';
import '../../repositories/payment_repository.dart';
import '../../repositories/session_repository.dart';
import '../../repositories/tutors_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_transitions.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/zelp_ui_components.dart';
import 'manual_payment_screen.dart';
import 'session_details_screen.dart';
import 'sessions_calendar_screen.dart';
import 'zelp_tutor_profile_screen.dart';

class ZelpSessionsScreen extends StatefulWidget {
  const ZelpSessionsScreen({super.key});

  @override
  State<ZelpSessionsScreen> createState() => _ZelpSessionsScreenState();
}

class _ZelpSessionsScreenState extends State<ZelpSessionsScreen> {
  final SessionRepository _sessionRepository = SessionRepository();
  final PaymentRepository _paymentRepository = PaymentRepository();
  final TutorsRepository _tutorsRepository = TutorsRepository();

  final List<String> _filters = const [
    'All',
    'Pending',
    'Approved',
    'Past Sessions',
  ];
  int _filterIndex = 0;

  String _sessionFilterLabel(SessionModel session) {
    final raw = session.status.toLowerCase();
    if (raw == 'pending' ||
        raw == 'pending_payment_verification' ||
        raw.contains('pending')) {
      return 'Pending';
    }
    if (raw == 'approved' || raw == 'confirmed' || raw == 'booked') {
      return 'Approved';
    }
    return 'All';
  }



  Future<void> _confirmCancel(
    BuildContext context,
    SessionModel session,
  ) async {
    Navigator.of(context).push(
      AppTransitions.slideFromRight(
        page: SessionDetailsScreen(
          sessionId: session.id,
          showCancelDialog: true,
        ),
      ),
    );
  }

  Future<void> _rebookSession(
    BuildContext context,
    SessionModel session,
  ) async {
    try {
      final tutor = await _tutorsRepository.getTutorById(session.tutorId).first;
      if (!context.mounted) return;

      if (tutor == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tutor profile is unavailable right now.'),
          ),
        );
        return;
      }

      Navigator.of(context).push(
        AppTransitions.slideFromRight(
          page: ZelpTutorProfileScreen(tutor: tutor),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open tutor profile: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: const Text('My Sessions')),
        body: const Center(child: Text('Please sign in to view sessions.')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('My Sessions'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(
                context,
              ).push(AppTransitions.fade(page: const SessionsCalendarScreen()));
            },
            icon: const Icon(Icons.calendar_month),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Payment Updates Box (if any)
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _paymentRepository.userNotifications(currentUser.uid),
              builder: (context, snapshot) {
                final docs =
                    snapshot.data?.docs ??
                    <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                final unread = docs
                    .where((d) => d.data()['read'] != true)
                    .toList();

                if (unread.isEmpty) return const SizedBox.shrink();

                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.fromBorderSide(AppTheme.border()),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.notifications_active_outlined,
                              size: 16,
                              color: AppTheme.primary,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Payment Updates',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...unread.take(2).map((doc) {
                          final data = doc.data();
                          final title = (data['title'] ?? 'Payment update')
                              .toString();
                          final message = (data['message'] ?? '').toString();
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              message,
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: TextButton(
                              onPressed: () {
                                _paymentRepository.markNotificationRead(doc.id);
                              },
                              child: const Text('Mark read'),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Horizontal Filter Tabs
            Padding(
              padding: const EdgeInsets.all(16),
              child: ZelpCategoryTabs(
                items: _filters,
                selectedIndex: _filterIndex,
                onChanged: (value) => setState(() => _filterIndex = value),
              ),
            ),

            Expanded(
              child: StreamBuilder<List<SessionModel>>(
                stream: _sessionRepository.allStudentSessions(
                  currentUser.uid,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const AppLoadingIndicator(
                      message: 'Loading sessions...',
                    );
                  }

                  final sessions = snapshot.data ?? [];
                  final filteredSessions = sessions.where((s) {
                    final isCompleted = s.status.toLowerCase() == 'completed';
                    final tabName = _filters[_filterIndex];

                    if (tabName == 'Past Sessions') {
                      return isCompleted;
                    } else {
                      // Do not show completed sessions under other tabs
                      if (isCompleted) return false;

                      if (tabName == 'All') {
                        return true;
                      } else {
                        return _sessionFilterLabel(s) == tabName;
                      }
                    }
                  }).toList();

                  if (filteredSessions.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _filterIndex == 0
                              ? 'No sessions scheduled yet.'
                              : 'No ${_filters[_filterIndex]} sessions found.',
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: filteredSessions.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final session = filteredSessions[index];
                      final dayStr = session.dateTime.day.toString();
                      final monthStr = DateFormat(
                        'MMM',
                      ).format(session.dateTime).toUpperCase();
                      final timeStr = DateFormat.jm().format(session.dateTime);
                      final durationStr = '${session.durationMinutes} min';
                      final isPast = session.dateTime.isBefore(DateTime.now());

                      // Determine state buttons
                      String primaryLabel = 'Details';
                      String secondaryLabel = isPast ? 'Rebook' : 'Cancel';

                      if (session.status == 'payment_rejected') {
                        primaryLabel = 'Upload Proof';
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ZelpSessionCard(
                            data: ZelpSessionCardData(
                              tutorName: session.tutorName ?? session.tutorId,
                              subject: session.subject,
                              time: timeStr,
                              duration: durationStr,
                              status: session.status,
                              day: dayStr,
                              month: monthStr,
                              joinLabel: primaryLabel,
                              secondaryLabel: secondaryLabel,
                              enabled: true,
                            ),
                            onPrimaryTap: () {
                              if (session.status == 'payment_rejected') {
                                Navigator.of(context).push(
                                  AppTransitions.slideFromRight(
                                    page: ManualPaymentScreen(
                                      sessionId: session.id,
                                      tutorId: session.tutorId,
                                      subject: session.subject,
                                      date: DateFormat(
                                        'yyyy-MM-dd',
                                      ).format(session.dateTime),
                                      time: DateFormat(
                                        'HH:mm',
                                      ).format(session.dateTime),
                                      timeDisplay: DateFormat.jm().format(
                                        session.dateTime,
                                      ),
                                      sessionDateTime: session.dateTime,
                                      amount: session.amount,
                                      durationMinutes: session.durationMinutes,
                                      slotCount: session.slotCount,
                                      reservedSlots:
                                          session.reservedSlots.isNotEmpty
                                          ? session.reservedSlots
                                          : <String>[
                                              DateFormat(
                                                'HH:mm',
                                              ).format(session.dateTime),
                                            ],
                                    ),
                                  ),
                                );
                              } else {
                                Navigator.of(context).push(
                                  AppTransitions.slideFromRight(
                                    page: SessionDetailsScreen(
                                      sessionId: session.id,
                                    ),
                                  ),
                                );
                              }
                            },
                            onSecondaryTap: () {
                              if (isPast) {
                                _rebookSession(context, session);
                              } else {
                                _confirmCancel(context, session);
                              }
                            },
                          ),
                          if (session.status == 'approved' || session.status == 'confirmed') ...[
                            const SizedBox(height: 8),
                            if (session.meetLink != null && session.meetLink!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.link_rounded, color: Color(0xFF475569), size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        session.meetLink!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1E293B),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () {
                                        Clipboard.setData(ClipboardData(text: session.meetLink!));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Link copied to clipboard!'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                      child: const Icon(Icons.copy_rounded, color: Color(0xFF4051B5), size: 18),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFFDE68A)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 18),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Meeting link will be posted by the tutor.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFB45309),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                          if (session.status == 'pending_payment_verification')
                            const Padding(
                              padding: EdgeInsets.only(top: 6, left: 4),
                              child: Text(
                                'Waiting for payment confirmation',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
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
          ],
        ),
      ),
    );
  }
}
