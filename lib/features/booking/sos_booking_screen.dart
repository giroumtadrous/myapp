import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/sos_request_model.dart';
import '../../theme/app_theme.dart';

class SosBookingScreen extends StatefulWidget {
  const SosBookingScreen({super.key});

  @override
  State<SosBookingScreen> createState() => _SosBookingScreenState();
}

class _SosBookingScreenState extends State<SosBookingScreen>
    with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;

  // Steps: 0 = subject picker, 1 = searching, 2 = result
  int _step = 0;
  String _selectedSubject = '';
  String? _sosRequestId;
  bool _creating = false;

  late AnimationController _pulseController;
  Timer? _countdownTimer;
  Duration _remaining = const Duration(hours: 1);

  static const _subjects = [
    'Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
    'Computer Science',
    'English',
    'Arabic',
    'Engineering',
    'Business',
    'Other',
  ];

  static const _subjectIcons = {
    'Mathematics': Icons.calculate_outlined,
    'Physics': Icons.science_outlined,
    'Chemistry': Icons.biotech_outlined,
    'Biology': Icons.eco_outlined,
    'Computer Science': Icons.computer_outlined,
    'English': Icons.translate_outlined,
    'Arabic': Icons.language_outlined,
    'Engineering': Icons.engineering_outlined,
    'Business': Icons.business_center_outlined,
    'Other': Icons.school_outlined,
  };

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _remaining = const Duration(hours: 1);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _remaining -= const Duration(seconds: 1);
        if (_remaining.isNegative) {
          _remaining = Duration.zero;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _createSosRequest() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _selectedSubject.isEmpty) return;

    setState(() => _creating = true);

    try {
      final now = DateTime.now();
      final docRef = await _firestore.collection('sos_requests').add({
        'studentId': uid,
        'subject': _selectedSubject,
        'status': 'searching',
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(now.add(const Duration(hours: 1))),
      });

      // Find all tutors who teach this subject
      final tutorsSnapshot = await _firestore
          .collection('tutors')
          .where('subjects', arrayContains: _selectedSubject)
          .get();

      // Write a notification document for each matching tutor (excluding oneself if registered)
      final batch = _firestore.batch();
      for (final doc in tutorsSnapshot.docs) {
        final tutorData = doc.data();
        final authUid = tutorData['authUid']?.toString();
        if (authUid != null && authUid.isNotEmpty && authUid != uid) {
          final notifRef = _firestore.collection('notifications').doc();
          batch.set(notifRef, {
            'userId': authUid,
            'type': 'sos_request',
            'sosRequestId': docRef.id,
            'subject': _selectedSubject,
            'title': '🆘 SOS Tutoring Request!',
            'message': 'A student needs help with $_selectedSubject right now.',
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
      await batch.commit();

      if (!mounted) return;
      setState(() {
        _sosRequestId = docRef.id;
        _step = 1;
        _creating = false;
      });
      _startCountdown();
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create SOS request: $e')),
      );
    }
  }

  Future<void> _cancelRequest() async {
    if (_sosRequestId == null) return;
    try {
      await _firestore.collection('sos_requests').doc(_sosRequestId!).update({
        'status': 'failed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours}:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        title: const Text('SOS Tutoring'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _step == 0
            ? _buildSubjectPicker(isDark)
            : _buildSearching(isDark),
      ),
    );
  }

  // ── Step 1: Subject Picker ──────────────────────────────────────────────────
  Widget _buildSubjectPicker(bool isDark) {
    return SingleChildScrollView(
      key: const ValueKey('subject-picker'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Emergency header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFF97316)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Text(
                  '🆘',
                  style: TextStyle(fontSize: 44),
                ),
                const SizedBox(height: 8),
                const Text(
                  'SOS Tutoring',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Find a tutor right now',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'What subject do you need help with?',
            style: TextStyle(
              color: isDark
                  ? AppTheme.darkTextPrimary
                  : AppTheme.lightTextPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),

          // Subject grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.5,
            children: _subjects.map((subject) {
              final selected = _selectedSubject == subject;
              return GestureDetector(
                onTap: () => setState(() => _selectedSubject = subject),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.primary.withValues(alpha: 0.15)
                        : (isDark
                            ? AppTheme.darkSurface
                            : AppTheme.lightSurface),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? AppTheme.primary
                          : (isDark
                              ? AppTheme.primary.withValues(alpha: 0.22)
                              : AppTheme.primary.withValues(alpha: 0.14)),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _subjectIcons[subject] ?? Icons.school_outlined,
                        size: 20,
                        color: selected
                            ? AppTheme.primary
                            : (isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.lightTextSecondary),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          subject,
                          style: TextStyle(
                            color: selected
                                ? AppTheme.primary
                                : (isDark
                                    ? AppTheme.darkTextPrimary
                                    : AppTheme.lightTextPrimary),
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Request Now button
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed:
                  _selectedSubject.isNotEmpty && !_creating ? _createSosRequest : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _creating
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.flash_on, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Request Now',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2: Searching / Result ──────────────────────────────────────────────
  Widget _buildSearching(bool isDark) {
    if (_sosRequestId == null) {
      return const Center(child: Text('Error: no request ID.'));
    }

    return StreamBuilder<DocumentSnapshot>(
      key: const ValueKey('searching'),
      stream:
          _firestore.collection('sos_requests').doc(_sosRequestId!).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: CircularProgressIndicator());
        }

        final request = SosRequestModel.fromFirestore(snapshot.data!);

        if (request.status == 'matched') {
          _countdownTimer?.cancel();
          return _buildMatched(isDark, request);
        }

        if (request.status == 'failed') {
          _countdownTimer?.cancel();
          return _buildFailed(isDark);
        }

        // Still searching
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pulsing circle
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final scale =
                        1.0 + (_pulseController.value * 0.15);
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFEF4444)
                                  .withValues(alpha: 0.8),
                              const Color(0xFFF97316)
                                  .withValues(alpha: 0.6),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEF4444)
                                  .withValues(alpha: 0.3 * _pulseController.value),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.search,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 28),
                Text(
                  'Searching for a tutor...',
                  style: TextStyle(
                    color: isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.lightTextPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedSubject,
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                // Countdown
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.darkSurface
                        : AppTheme.lightSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.fromBorderSide(
                        AppTheme.border(isDark: isDark)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 18,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Expires in ${_formatDuration(_remaining)}',
                        style: TextStyle(
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.lightTextSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                OutlinedButton(
                  onPressed: _cancelRequest,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  child: const Text(
                    'Cancel Request',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMatched(bool isDark, SosRequestModel request) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppTheme.primary,
                size: 56,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Tutor Found! 🎉',
              style: TextStyle(
                color: isDark
                    ? AppTheme.darkTextPrimary
                    : AppTheme.lightTextPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'A tutor has accepted your request for $_selectedSubject',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Go to Session',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailed(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sentiment_dissatisfied_outlined,
                color: Color(0xFFEF4444),
                size: 56,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Tutor Available',
              style: TextStyle(
                color: isDark
                    ? AppTheme.darkTextPrimary
                    : AppTheme.lightTextPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Unfortunately, no tutor is available right now. Please try again later.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Go Back'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _step = 0;
                        _sosRequestId = null;
                        _selectedSubject = '';
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Try Again'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
