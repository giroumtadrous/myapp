import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/wallet_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_loading_indicator.dart';

class PayoutRequestsScreen extends StatefulWidget {
  const PayoutRequestsScreen({super.key});

  @override
  State<PayoutRequestsScreen> createState() => _PayoutRequestsScreenState();
}

class _PayoutRequestsScreenState extends State<PayoutRequestsScreen> {
  final _firestore = FirebaseFirestore.instance;

  Stream<List<PayoutRequest>> _pendingPayoutsStream() {
    return _firestore
        .collection('payout_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snap) async {
      final requests = snap.docs
          .map((doc) => PayoutRequest.fromFirestore(doc))
          .toList();

      // Enrich with tutor names if not already set
      for (var i = 0; i < requests.length; i++) {
        if ((requests[i].tutorName ?? '').isEmpty) {
          try {
            final tutorDoc = await _firestore
                .collection('tutors')
                .doc(requests[i].tutorId)
                .get();
            if (tutorDoc.exists) {
              final name =
                  (tutorDoc.data()?['name'] ?? 'Unknown Tutor').toString();
              requests[i] = PayoutRequest(
                id: requests[i].id,
                tutorId: requests[i].tutorId,
                amount: requests[i].amount,
                status: requests[i].status,
                createdAt: requests[i].createdAt,
                paidAt: requests[i].paidAt,
                tutorName: name,
              );
            }
          } catch (_) {}
        }
      }

      return requests;
    });
  }

  Future<void> _markAsPaid(PayoutRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Payout'),
        content: Text(
          'Mark EGP ${request.amount.toStringAsFixed(0)} payout to '
          '${request.tutorName ?? 'tutor'} as paid?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm Paid'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Update payout request status
      await _firestore.collection('payout_requests').doc(request.id).update({
        'status': 'paid',
        'paidAt': FieldValue.serverTimestamp(),
      });

      // Update tutor wallet summary
      final walletSummaryRef = _firestore
          .collection('tutors')
          .doc(request.tutorId)
          .collection('wallet')
          .doc('summary');

      await walletSummaryRef.set({
        'pendingPayout': FieldValue.increment(-request.amount),
        'paidOut': FieldValue.increment(request.amount),
      }, SetOptions(merge: true));

      // Update wallet transactions from pending_payout to paid
      final txSnap = await _firestore
          .collection('tutors')
          .doc(request.tutorId)
          .collection('wallet')
          .doc('transactions')
          .collection('items')
          .where('status', isEqualTo: 'pending_payout')
          .get();

      final batch = _firestore.batch();
      for (final doc in txSnap.docs) {
        batch.update(doc.reference, {'status': 'paid'});
      }
      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payout marked as paid ✓'),
          backgroundColor: AppTheme.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to process payout: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(title: const Text('Payout Requests')),
      body: StreamBuilder<List<PayoutRequest>>(
        stream: _pendingPayoutsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingIndicator(
                message: 'Loading payout requests...');
          }

          final requests = snapshot.data ?? [];

          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No pending payout requests',
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final request = requests[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.fromBorderSide(
                      AppTheme.border(isDark: isDark)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.payments_outlined,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                request.tutorName ?? 'Unknown Tutor',
                                style: TextStyle(
                                  color: isDark
                                      ? AppTheme.darkTextPrimary
                                      : AppTheme.lightTextPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              if (request.createdAt != null) ...[
                                const SizedBox(height: 3),
                                Text(
                                  DateFormat.yMMMd()
                                      .add_jm()
                                      .format(request.createdAt!),
                                  style: TextStyle(
                                    color: isDark
                                        ? AppTheme.darkTextSecondary
                                        : AppTheme.lightTextSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          'EGP ${request.amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Color(0xFFF59E0B),
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _markAsPaid(request),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Mark as Paid'),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
