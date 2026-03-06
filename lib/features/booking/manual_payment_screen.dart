import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../repositories/payment_repository.dart';
import '../dashboard/main_navigation_screen.dart';

class ManualPaymentScreen extends StatefulWidget {
  const ManualPaymentScreen({
    super.key,
    required this.sessionId,
    required this.tutorId,
    required this.subject,
    required this.date,
    required this.time,
    required this.timeDisplay,
    required this.sessionDateTime,
    required this.amount,
  });

  final String sessionId;
  final String tutorId;
  final String subject;
  final String date;
  final String time;
  final String timeDisplay;
  final DateTime sessionDateTime;
  final double amount;

  @override
  State<ManualPaymentScreen> createState() => _ManualPaymentScreenState();
}

class _ManualPaymentScreenState extends State<ManualPaymentScreen> {
  static const String _instaPayNumber = '+201283567813';

  final PaymentRepository _paymentRepository = PaymentRepository();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _screenshotUrlController = TextEditingController();

  DateTime? _transferTime;
  bool _submitting = false;

  @override
  void dispose() {
    _timeController.dispose();
    _noteController.dispose();
    _screenshotUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickTransferDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 7)),
      lastDate: now,
      initialDate: _transferTime ?? now,
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_transferTime ?? now),
    );
    if (pickedTime == null || !mounted) return;

    final value = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      _transferTime = value;
      _timeController.text = DateFormat('yyyy-MM-dd HH:mm').format(value);
    });
  }

  Future<void> _submit() async {
    print('[ManualPaymentUI] Submit tapped');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('[ManualPaymentUI] User missing. Abort submit');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in again.')),
      );
      return;
    }

    if (_screenshotUrlController.text.trim().isEmpty) {
      print('[ManualPaymentUI] Screenshot URL missing. Abort submit');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please paste a screenshot image URL.')),
      );
      return;
    }

    if (_transferTime == null) {
      print('[ManualPaymentUI] Transfer time missing. Abort submit');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide transfer time.')),
      );
      return;
    }

    final startedAt = DateTime.now();
    setState(() => _submitting = true);

    try {
      print('[ManualPaymentUI] Calling submitManualPayment...');
      await _paymentRepository.submitManualPayment(
        sessionId: widget.sessionId,
        studentId: user.uid,
        tutorId: widget.tutorId,
        subject: widget.subject,
        sessionDateTime: widget.sessionDateTime,
        date: widget.date,
        time: widget.time,
        timeDisplay: widget.timeDisplay,
        amount: widget.amount,
        transferTime: _transferTime!,
        screenshotUrl: _screenshotUrlController.text.trim(),
        note: _noteController.text,
      );

      final totalMs = DateTime.now().difference(startedAt).inMilliseconds;
      print('[ManualPaymentUI] submitManualPayment completed in ${totalMs}ms');

      if (!mounted) return;

      print('[ManualPaymentUI] Navigating to main screen after success');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        (route) => false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Payment submitted. Waiting for payment confirmation.',
          ),
        ),
      );
    } catch (e) {
      print('[ManualPaymentUI] Submit failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit payment: $e')),
      );
    } finally {
      print('[ManualPaymentUI] Submit finished. Releasing loading state');
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Pay with InstaPay')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment method',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Transfer using InstaPay to this number:',
                        style: textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        _instaPayNumber,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Session fee: \$${widget.amount.toStringAsFixed(2)}',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Payment proof',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Upload your screenshot to Google Drive (or similar) and paste the shareable link below:',
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _screenshotUrlController,
                enabled: !_submitting,
                decoration: const InputDecoration(
                  labelText: 'Screenshot image URL',
                  hintText: 'Paste the direct image link here (e.g., https://drive.google.com/...)',
                  suffixIcon: Icon(Icons.link_outlined),
                ),
                minLines: 2,
                maxLines: 3,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _timeController,
                readOnly: true,
                onTap: _submitting ? null : _pickTransferDateTime,
                decoration: const InputDecoration(
                  labelText: 'Transfer time',
                  hintText: 'Select transfer date and time',
                  suffixIcon: Icon(Icons.schedule_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _noteController,
                enabled: !_submitting,
                decoration: const InputDecoration(
                  labelText: 'Reference / note (optional)',
                  hintText: 'Transaction reference, sender name, etc.',
                ),
                minLines: 2,
                maxLines: 3,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit payment for verification'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
