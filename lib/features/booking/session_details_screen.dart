import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/session_model.dart';
import '../../models/tutor_model.dart';
import '../../repositories/reviews_repository.dart';
import '../../repositories/session_repository.dart';
import '../../repositories/tutors_repository.dart';
import '../../repositories/credits_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_transitions.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/zelp_ui_components.dart';
import 'zelp_tutor_profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/messaging_service.dart';
import '../messages/zelp_chat_screen.dart';

class SessionDetailsScreen extends StatefulWidget {
  final String sessionId;
  final bool showCancelDialog;

  const SessionDetailsScreen({
    super.key,
    required this.sessionId,
    this.showCancelDialog = false,
  });

  @override
  State<SessionDetailsScreen> createState() => _SessionDetailsScreenState();
}

class _SessionDetailsScreenState extends State<SessionDetailsScreen> {
  final SessionRepository _sessionRepository = SessionRepository();
  final ReviewsRepository _reviewsRepository = ReviewsRepository();
  final TutorsRepository _tutorsRepository = TutorsRepository();
  bool _isCanceling = false;
  bool _hasAutoShownCancelDialog = false;
  bool _submittingReview = false;


  Future<void> _cancelSessionByStudent(SessionModel session) async {
    final price = session.type == 'group' ? session.pricePerStudent : session.amount;
    final now = DateTime.now();
    final timeDiff = session.dateTime.difference(now);

    double refundPercentage = 0.0;
    if (timeDiff.inHours >= 12) {
      refundPercentage = 1.0;
    } else if (timeDiff.inHours >= 3) {
      refundPercentage = 0.5;
    } else {
      refundPercentage = 0.0;
    }

    final refundAmount = price * refundPercentage;
    final tutorEarnings = price * (1.0 - refundPercentage);

    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Session'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Are you sure you want to cancel this session?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• Time remaining: ${timeDiff.inHours} hours'),
                      Text('• Refund tier: ${(refundPercentage * 100).toStringAsFixed(0)}% credits'),
                      Text('• Credit Refund: EGP ${refundAmount.toStringAsFixed(0)}'),
                      Text('• Tutor earns: EGP ${tutorEarnings.toStringAsFixed(0)}'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason for cancellation',
                    border: OutlineInputBorder(),
                    hintText: 'e.g. Unforeseen circumstances',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a reason';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Go Back'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(context).pop(true);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCanceling = true);
    try {
      await CreditsRepository.instance.cancelSessionByStudent(
        sessionId: session.id,
        studentId: session.studentId,
        reason: reasonController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Session cancelled. Refunded EGP ${refundAmount.toStringAsFixed(0)} credits.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel: $e')),
      );
    } finally {
      if (mounted) setState(() => _isCanceling = false);
    }
  }

  Future<void> _cancelSessionByTutor(SessionModel session) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Session (Tutor)'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Are you sure you want to cancel this session?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WARNING:',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text('• Student gets 100% credit refund.'),
                      Text('• You will receive 1 strike on your profile.'),
                      Text('• At 3 strikes, your account will be suspended.'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason for cancellation',
                    border: OutlineInputBorder(),
                    hintText: 'e.g. Schedule conflict',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a reason';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Go Back'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(context).pop(true);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirm Cancel & Accept Strike'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCanceling = true);
    try {
      await CreditsRepository.instance.cancelSessionByTutor(
        sessionId: session.id,
        tutorId: session.tutorId,
        reason: reasonController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session cancelled. Strike has been issued.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel: $e')),
      );
    } finally {
      if (mounted) setState(() => _isCanceling = false);
    }
  }

  Future<void> _reportNoShow(SessionModel session) async {
    final price = session.type == 'group' ? session.pricePerStudent : session.amount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Tutor No-Show'),
        content: Text(
          'Are you sure you want to report that the tutor did not show up?\n\n'
          'You will get a 100% refund of EGP ${price.toStringAsFixed(0)} credits, and the tutor will receive 1 strike.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Report No-Show'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCanceling = true);
    try {
      await CreditsRepository.instance.reportNoShow(
        sessionId: session.id,
        studentId: session.studentId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted. 100% refund has been issued.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to report: $e')),
      );
    } finally {
      if (mounted) setState(() => _isCanceling = false);
    }
  }

  Future<void> _raiseDispute(SessionModel session) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Raise a Dispute'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Submit a dispute for this session if you encountered issues. Admin will review the case.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: reasonController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Reason for dispute',
                    border: OutlineInputBorder(),
                    hintText: 'Describe what went wrong in detail...',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a reason';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(context).pop(true);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('Submit Dispute'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCanceling = true);
    try {
      await CreditsRepository.instance.raiseDispute(
        sessionId: session.id,
        reason: reasonController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dispute raised successfully. Admin has been notified.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to raise dispute: $e')),
      );
    } finally {
      if (mounted) setState(() => _isCanceling = false);
    }
  }

  Future<void> _openDocument(SessionDocument document) async {
    final uri = Uri.tryParse(document.url);
    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid document URL.')));
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open document link.')),
      );
    }
  }

  bool _canReview(SessionModel session, User? user) {
    if (user == null) return false;
    return session.status.toLowerCase() == 'completed' &&
        session.studentId.trim() == user.uid;
  }

  bool _isCancelled(SessionModel session) {
    return session.status.toLowerCase() == 'cancelled';
  }

  String _refundStatusLabel(SessionModel session) {
    final status = (session.refundStatus ?? '').trim().toLowerCase();
    if (session.refundDone == true ||
        session.refundedAt != null ||
        session.refundProcessedAt != null ||
        status == 'done' ||
        status == 'refunded' ||
        status == 'completed') {
      return 'Refund done';
    }

    if (session.refundDone == false ||
        status == 'pending' ||
        status == 'requested' ||
        status == 'processing' ||
        status == 'in_progress') {
      return 'Refund pending';
    }

    return 'Refund pending admin review';
  }

  Widget _refundStatusChip(SessionModel session) {
    final label = _refundStatusLabel(session);
    final isDone = label == 'Refund done';
    final background = isDone
        ? const Color(0xFFE8F5E9)
        : const Color(0xFFFFF4E5);
    final foreground = isDone
        ? const Color(0xFF166534)
        : const Color(0xFF9A3412);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.fromBorderSide(
          BorderSide(color: foreground.withValues(alpha: 0.18)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isDone ? Icons.verified_outlined : Icons.schedule_outlined,
            size: 18,
            color: foreground,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Future<void> _openTutorProfile(Tutor tutor) async {
    if (!mounted) return;
    Navigator.of(context).push(
      AppTransitions.slideFromRight(page: ZelpTutorProfileScreen(tutor: tutor)),
    );
  }

  Future<void> _showReviewDialog(SessionModel session) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final textController = TextEditingController();
    var selectedRating = 5;

    final submit = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Rate this session'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('How was your session with this tutor?'),
                  const SizedBox(height: 12),
                  Row(
                    children: List.generate(5, (index) {
                      final isFilled = index < selectedRating;
                      return IconButton(
                        onPressed: () {
                          setDialogState(() {
                            selectedRating = index + 1;
                          });
                        },
                        icon: Icon(
                          isFilled
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: Colors.amber,
                        ),
                      );
                    }),
                  ),
                  TextField(
                    controller: textController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Write a short review (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Submit Review'),
                ),
              ],
            );
          },
        );
      },
    );

    if (submit != true) {
      textController.dispose();
      return;
    }

    if (!mounted) {
      textController.dispose();
      return;
    }

    setState(() => _submittingReview = true);
    try {
      await _reviewsRepository.submitReview(
        sessionId: session.id,
        tutorId: session.tutorId,
        studentId: user.uid,
        rating: selectedRating.toDouble(),
        reviewText: textController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to submit review: $e')));
    } finally {
      textController.dispose();
      if (mounted) setState(() => _submittingReview = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Session Details'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          StreamBuilder<SessionDetailsData?>(
            stream: _sessionRepository.streamSessionDetails(widget.sessionId),
            builder: (context, snapshot) {
              final details = snapshot.data;
              if (details == null) return const SizedBox.shrink();

              final session = details.session;
              final currentUserId = FirebaseAuth.instance.currentUser?.uid;
              if (currentUserId == null) return const SizedBox.shrink();

              final isTutor = currentUserId != session.studentId;
              final myParticipantId = isTutor ? session.tutorId : session.studentId;
              final otherUserId = isTutor ? session.studentId : session.tutorId;

              return IconButton(
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                onPressed: () async {
                  final chatId = MessagingService.instance.getChatId(myParticipantId, otherUserId);

                  final authUser = FirebaseAuth.instance.currentUser;
                  final authName = authUser?.displayName ?? (isTutor ? 'Tutor' : 'Student');
                  final authPhoto = authUser?.photoURL ?? '';

                  // Fetch current user details from Firestore
                  final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
                  final currentDisplayName = userDoc.exists
                      ? (userDoc.data()?['name'] ?? userDoc.data()?['displayName'] ?? authName)
                      : authName;
                  final currentPhotoURL = userDoc.exists
                      ? (userDoc.data()?['photoUrl'] ?? userDoc.data()?['profileImageUrl'] ?? authPhoto)
                      : authPhoto;

                  final currentUserMeta = ChatParticipantMetadata(
                    displayName: currentDisplayName,
                    photoURL: currentPhotoURL,
                  );

                  // Set other user metadata
                  String otherDisplayName = 'User';
                  String otherPhotoURL = '';

                  if (isTutor) {
                    // The other user is the student
                    otherDisplayName = session.studentName ?? 'Student';
                    final studentDoc = await FirebaseFirestore.instance.collection('users').doc(otherUserId).get();
                    if (studentDoc.exists) {
                      otherPhotoURL = (studentDoc.data()?['photoUrl'] ?? studentDoc.data()?['profileImageUrl'] ?? '');
                      final name = studentDoc.data()?['name'] ?? studentDoc.data()?['displayName'];
                      if (name != null) otherDisplayName = name.toString();
                    }
                  } else {
                    // The other user is the tutor
                    otherDisplayName = details.tutor.name;
                    otherPhotoURL = details.tutor.photoUrl ?? '';
                  }

                  final otherUserMeta = ChatParticipantMetadata(
                    displayName: otherDisplayName,
                    photoURL: otherPhotoURL,
                  );

                  if (!context.mounted) return;
                  Navigator.of(context).push(
                    AppTransitions.slideFromRight(
                      page: ZelpChatScreen(
                        chatId: chatId,
                        currentUserId: myParticipantId,
                        otherUserId: otherUserId,
                        currentUserMetadata: currentUserMeta,
                        otherUserMetadata: otherUserMeta,
                      ),
                    ),
                  );
                },
                tooltip: 'Chat with ${isTutor ? (session.studentName ?? "Student") : details.tutor.name}',
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<SessionDetailsData?>(
        stream: _sessionRepository.streamSessionDetails(widget.sessionId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingIndicator(message: 'Loading details...');
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load session details: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final details = snapshot.data;
          if (details == null) {
            return const Center(child: Text('Session not found.'));
          }

          final session = details.session;
          if (widget.showCancelDialog && !_hasAutoShownCancelDialog) {
            _hasAutoShownCancelDialog = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _cancelSessionByStudent(session);
            });
          }
          final currentUser = FirebaseAuth.instance.currentUser;
          final cancelled = _isCancelled(session);
          final isTutor = currentUser?.uid != session.studentId;
          final isStudent = !isTutor;

          final canStudentCancel = isStudent &&
              (session.status == 'confirmed' || session.status == 'approved') &&
              session.dateTime.difference(DateTime.now()) >= const Duration(hours: 1);

          final terminalStatuses = ['cancelled', 'completed', 'rejected', 'no show', 'payment_rejected'];
          final canTutorCancel = isTutor && !terminalStatuses.contains(session.status.toLowerCase());

          final allowedNoShowTime = session.dateTime.add(const Duration(minutes: 15));
          final canReportNoShow = isStudent &&
              (session.status == 'confirmed' || session.status == 'approved') &&
              DateTime.now().isAfter(allowedNoShowTime) &&
              session.noShowReported != true;

          final completionTime = session.dateTime.add(Duration(minutes: session.durationMinutes));
          final now = DateTime.now();
          final within24HoursOfCompletion = now.isAfter(completionTime) && now.isBefore(completionTime.add(const Duration(hours: 24)));
          final canRaiseDispute = isStudent &&
              session.status == 'completed' &&
              within24HoursOfCompletion &&
              session.disputeStatus == null;

          final canReview = _canReview(session, currentUser);
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: AppTheme.buttonGradient,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: AppTheme.glow(alpha: 0.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  session.subject,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.background,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.background.withValues(
                                    alpha: 0.14,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  _titleCase(session.status).toUpperCase(),
                                  style: const TextStyle(
                                    color: AppTheme.background,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            details.tutor.name,
                            style: const TextStyle(
                              color: AppTheme.background,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _InfoChip(
                                icon: Icons.schedule_rounded,
                                label:
                                    '${DateFormat.yMMMd().format(session.dateTime)} · ${DateFormat.jm().format(session.dateTime)}',
                              ),
                              _InfoChip(
                                icon: Icons.timelapse_rounded,
                                label: '${session.durationMinutes} min',
                              ),
                              _InfoChip(
                                icon: Icons.video_call_rounded,
                                label: 'In-App session',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'SESSION OVERVIEW',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _SectionCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  session.subject,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Tutor session',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: AppTheme.textSecondary),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${DateFormat.yMMMd().format(session.dateTime)}, ${DateFormat.jm().format(session.dateTime)}',
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              gradient: AppTheme.buttonGradient,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.school_rounded,
                              color: AppTheme.background,
                              size: 32,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'PARTICIPANTS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _SectionCard(
                      child: _PersonTile(
                        name: details.tutor.name,
                        photoUrl: details.tutor.photoUrl,
                        fallbackIcon: Icons.school_outlined,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _SectionCard(
                      child: _PersonTile(
                        name: details.student.name,
                        photoUrl: null,
                        fallbackIcon: Icons.person_outline,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _MetaBox(
                            'Duration',
                            '${session.durationMinutes} min',
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: _MetaBox('Platform', 'In-App Video'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (canReview)
                      FutureBuilder<bool>(
                        future: _reviewsRepository.hasReviewForSession(
                          session.id,
                        ),
                        builder: (context, reviewSnapshot) {
                          if (reviewSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: LinearProgressIndicator(minHeight: 2),
                            );
                          }

                          final alreadyReviewed = reviewSnapshot.data ?? false;
                          return _SectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  alreadyReviewed
                                      ? 'You already reviewed this session.'
                                      : 'Rate & review this completed session',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                FilledButton.icon(
                                  onPressed:
                                      alreadyReviewed || _submittingReview
                                      ? null
                                      : () => _showReviewDialog(session),
                                  icon: _submittingReview
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.rate_review_outlined),
                                  label: Text(
                                    _submittingReview
                                        ? 'Submitting...'
                                        : alreadyReviewed
                                        ? 'Review Submitted'
                                        : 'Write a Review',
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    if (canReview) const SizedBox(height: 14),
                    const Text(
                      'NOTES',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _SectionCard(
                      child: Text(
                        session.notes.trim().isEmpty
                            ? 'No notes added for this session.'
                            : session.notes,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'RESOURCES',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (session.documents.isEmpty)
                      const _SectionCard(child: Text('No documents uploaded.'))
                    else
                      ...session.documents.map(
                        (doc) => _SectionCard(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.description_outlined),
                            title: Text(doc.name),
                            subtitle: Text(doc.type ?? 'Document'),
                            trailing: const Icon(Icons.download_outlined),
                            onTap: () => _openDocument(doc),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  border: Border(top: AppTheme.border()),
                ),
                child: cancelled
                    ? StreamBuilder<Tutor?>(
                        stream: _tutorsRepository.getTutorById(session.tutorId),
                        builder: (context, tutorSnapshot) {
                          final tutor = tutorSnapshot.data;
                          return Column(
                            children: [
                              _refundStatusChip(session),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ZelpPrimaryButton(
                                  label:
                                      tutorSnapshot.connectionState ==
                                          ConnectionState.waiting
                                      ? 'Loading tutor...'
                                      : 'Rebook with Tutor',
                                  icon: Icons.refresh_rounded,
                                  onTap: tutor == null
                                      ? null
                                      : () => _openTutorProfile(tutor),
                                ),
                              ),
                            ],
                          );
                        },
                      )
                    : Column(
                        children: [
                          if (session.meetLink != null && session.meetLink!.isNotEmpty) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'MEETING LINK',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                      color: Color(0xFF475569),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          session.meetLink!,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1E293B),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton.filledTonal(
                                        onPressed: () {
                                          Clipboard.setData(ClipboardData(text: session.meetLink!));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Link copied to clipboard!'),
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.copy_rounded, size: 18),
                                        style: IconButton.styleFrom(
                                          backgroundColor: const Color(0xFFE2E8F0),
                                          foregroundColor: const Color(0xFF475569),
                                        ),
                                        tooltip: 'Copy link',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Meeting link will be posted by the tutor.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFFB45309),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          if (canStudentCancel) ...[
                            SizedBox(
                              width: double.infinity,
                              child: ZelpSecondaryButton(
                                label: _isCanceling ? 'Cancelling...' : 'Cancel Session',
                                icon: _isCanceling ? null : Icons.cancel_outlined,
                                onTap: _isCanceling ? null : () => _cancelSessionByStudent(session),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (canTutorCancel) ...[
                            SizedBox(
                              width: double.infinity,
                              child: ZelpSecondaryButton(
                                label: _isCanceling ? 'Cancelling...' : 'Cancel Session',
                                icon: _isCanceling ? null : Icons.cancel_outlined,
                                onTap: _isCanceling ? null : () => _cancelSessionByTutor(session),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (canReportNoShow) ...[
                            SizedBox(
                              width: double.infinity,
                              child: ZelpPrimaryButton(
                                label: 'Report Tutor No-Show',
                                icon: Icons.report_problem_outlined,
                                onTap: _isCanceling ? null : () => _reportNoShow(session),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (canRaiseDispute) ...[
                            SizedBox(
                              width: double.infinity,
                              child: ZelpPrimaryButton(
                                label: 'Raise Dispute',
                                icon: Icons.gavel_outlined,
                                onTap: _isCanceling ? null : () => _raiseDispute(session),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _titleCase(String input) {
    if (input.isEmpty) return input;
    final text = input.replaceAll('_', ' ').trim();
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.fromBorderSide(AppTheme.border()),
      ),
      padding: const EdgeInsets.all(14),
      child: child,
    );
  }
}

class _MetaBox extends StatelessWidget {
  final String title;
  final String value;

  const _MetaBox(this.title, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.fromBorderSide(AppTheme.border()),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.background.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.fromBorderSide(
          BorderSide(color: AppTheme.background.withValues(alpha: 0.18)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppTheme.background),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.background,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final IconData fallbackIcon;

  const _PersonTile({
    required this.name,
    required this.photoUrl,
    required this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    final url = (photoUrl ?? '').trim();
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
          child: url.isEmpty ? Icon(fallbackIcon) : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
