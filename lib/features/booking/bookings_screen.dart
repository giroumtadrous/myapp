import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../models/session_model.dart';
import '../../repositories/payment_repository.dart';
import '../../repositories/session_repository.dart';
import '../../services/jitsi_meet_service.dart';
import '../../widgets/session_card.dart';
import 'manual_payment_screen.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  final SessionRepository _sessionRepository = SessionRepository();
  final PaymentRepository _paymentRepository = PaymentRepository();

  String _meetingDisplayName(User user) {
    final displayName = (user.displayName ?? '').trim();
    if (displayName.isNotEmpty) return displayName;

    final email = (user.email ?? '').trim();
    if (email.isNotEmpty) return email.split('@').first;

    return 'Student';
  }

  Future<void> _startMeeting(SessionModel session, User user) async {
    try {
      final roomName = await _sessionRepository.ensureSessionRoomName(
        session.id,
        existingRoomName: session.roomName,
      );

      await JitsiMeetService.instance.startMeeting(
        roomName: roomName,
        userName: _meetingDisplayName(user),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not join session: $e')));
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'booked':
      case 'confirmed':
        return Colors.green;
      case 'pending_payment_verification':
        return Colors.orange;
      case 'payment_rejected':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending_payment_verification':
        return 'Pending';
      case 'payment_rejected':
        return 'Payment Rejected';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My bookings')),
        body: const Center(child: Text('Please sign in to view bookings.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My bookings')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Upcoming sessions',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _paymentRepository.userNotifications(user.uid),
                builder: (context, snapshot) {
                  final docs =
                      snapshot.data?.docs ??
                      <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                  final unread = docs.where((d) {
                    final value = d.data()['read'];
                    return value != true;
                  }).toList();

                  if (unread.isEmpty) return const SizedBox.shrink();

                  return Card(
                    color: Colors.amber[50],
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: unread.take(2).map((doc) {
                          final data = doc.data();
                          final title = (data['title'] ?? 'Payment update')
                              .toString();
                          final message = (data['message'] ?? '').toString();
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(title),
                            subtitle: Text(message),
                            trailing: TextButton(
                              onPressed: () {
                                _paymentRepository.markNotificationRead(doc.id);
                              },
                              child: const Text('Mark read'),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<List<SessionModel>>(
                  stream: _sessionRepository.upcomingSessions(user.uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final sessions = snapshot.data ?? [];
                    if (sessions.isEmpty) {
                      return Center(
                        child: Text(
                          'No upcoming sessions yet.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: sessions.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        final isSessionConfirmed = session.status == 'confirmed';

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SessionCard(
                              tutorName: session.tutorName ?? session.tutorId,
                              subject: session.subject,
                              date: DateFormat.yMMMd().format(session.dateTime),
                              timeRange: DateFormat.jm().format(
                                session.dateTime,
                              ),
                              statusLabel: _statusLabel(session.status),
                              statusColor: _statusColor(session.status),
                              isActive: false,
                                onJoinMeet: isSessionConfirmed
                                  ? () => _startMeeting(session, user)
                                  : null,
                            ),
                            if (session.status ==
                                'pending_payment_verification')
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Waiting for payment confirmation',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: Colors.orange[800],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            if (session.status == 'payment_rejected')
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ManualPaymentScreen(
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
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.upload_file_outlined),
                                  label: const Text(
                                    'Upload Correct Payment Proof',
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
      ),
    );
  }
}
