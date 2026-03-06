import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/payment_model.dart';
import '../../repositories/payment_repository.dart';

class PaymentVerificationScreen extends StatefulWidget {
  const PaymentVerificationScreen({super.key});

  @override
  State<PaymentVerificationScreen> createState() =>
      _PaymentVerificationScreenState();
}

class _PaymentVerificationScreenState extends State<PaymentVerificationScreen> {
  final PaymentRepository _paymentRepository = PaymentRepository();

  Future<void> _verify(PaymentModel payment, bool approved) async {
    try {
      await _paymentRepository.verifyPayment(
        paymentId: payment.id,
        sessionId: payment.sessionId,
        studentId: payment.studentId,
        approved: approved,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approved
                ? 'Payment approved and session booked.'
                : 'Payment rejected. Student notified.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Verification'),
      ),
      body: SafeArea(
        child: StreamBuilder<List<PaymentModel>>(
          stream: _paymentRepository.pendingPayments(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final payments = snapshot.data ?? <PaymentModel>[];
            if (payments.isEmpty) {
              return Center(
                child: Text(
                  'No pending payments.',
                  style: textTheme.bodyLarge,
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: payments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final payment = payments[index];
                return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: FirebaseFirestore.instance
                      .collection('sessions')
                      .doc(payment.sessionId)
                      .get(),
                  builder: (context, sessionSnap) {
                    final sessionData = sessionSnap.data?.data();
                    final subject =
                        (sessionData?['subject'] ?? 'Unknown').toString();

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Session ${payment.sessionId}',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('Student: ${payment.studentId}'),
                            Text('Tutor: ${payment.tutorId}'),
                            Text('Subject: $subject'),
                            Text(
                              'Amount: \$${payment.amount.toStringAsFixed(2)}',
                            ),
                            Text(
                              'Transfer time: ${DateFormat('yyyy-MM-dd HH:mm').format(payment.transferTime)}',
                            ),
                            if ((payment.note ?? '').trim().isNotEmpty)
                              Text('Note: ${payment.note}'),
                            const SizedBox(height: 10),
                            InkWell(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => _ScreenshotPreviewScreen(
                                      url: payment.screenshotUrl,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                height: 180,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: Colors.grey[200],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Image.network(
                                  payment.screenshotUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Center(
                                    child: Text('Unable to load screenshot'),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _verify(payment, true),
                                    child: const Text('Approve'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _verify(payment, false),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red[700],
                                    ),
                                    child: const Text('Reject'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ScreenshotPreviewScreen extends StatelessWidget {
  const _ScreenshotPreviewScreen({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Screenshot')),
      body: SafeArea(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Center(
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const Text('Unable to load screenshot'),
            ),
          ),
        ),
      ),
    );
  }
}
