import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/session_model.dart';
import '../../repositories/reviews_repository.dart';
import '../../repositories/session_repository.dart';
import '../../services/jitsi_meet_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/zelp_ui_components.dart';

class SessionDetailsScreen extends StatefulWidget {
  final String sessionId;

  const SessionDetailsScreen({super.key, required this.sessionId});

  @override
  State<SessionDetailsScreen> createState() => _SessionDetailsScreenState();
}

class _SessionDetailsScreenState extends State<SessionDetailsScreen> {
  final SessionRepository _sessionRepository = SessionRepository();
  final ReviewsRepository _reviewsRepository = ReviewsRepository();
  bool _isCanceling = false;
  bool _isJoining = false;
  bool _submittingReview = false;

  Future<void> _joinSession(SessionModel session) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to join this session.')),
      );
      return;
    }

    setState(() => _isJoining = true);
    try {
      await JitsiMeetService.instance.startMeeting(
        context: context,
        sessionId: session.id,
        tutorId: session.tutorId,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not join session: $e')));
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  Future<void> _cancelSession(SessionModel session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel session'),
        content: const Text(
          'Are you sure you want to cancel this session? This updates the status to cancelled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCanceling = true);
    try {
      await _sessionRepository.cancelSession(session.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session cancelled successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to cancel session: $e')));
    } finally {
      if (mounted) {
        setState(() => _isCanceling = false);
      }
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

  bool _canCancel(SessionModel session) {
    final status = session.status.toLowerCase();
    return status != 'cancelled' &&
        status != 'completed' &&
        status != 'rejected';
  }

  bool _canReview(SessionModel session, User? user) {
    if (user == null) return false;
    return session.status.toLowerCase() == 'completed' &&
        session.studentId.trim() == user.uid;
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
                          isFilled ? Icons.star_rounded : Icons.star_border_rounded,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit review: $e')),
      );
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
          final currentUser = FirebaseAuth.instance.currentUser;
          final canJoin = _sessionRepository.canJoinSession(session);
          final canCancel = _canCancel(session);
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
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppTheme.background.withValues(alpha: 0.14),
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
                                label: '${DateFormat.yMMMd().format(session.dateTime)} · ${DateFormat.jm().format(session.dateTime)}',
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
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${DateFormat.yMMMd().format(session.dateTime)}, ${DateFormat.jm().format(session.dateTime)}',
                                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
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
                          child: _MetaBox('Duration', '${session.durationMinutes} min'),
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
                        future: _reviewsRepository.hasReviewForSession(session.id),
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
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                FilledButton.icon(
                                  onPressed: alreadyReviewed || _submittingReview
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
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ZelpPrimaryButton(
                        label: _isJoining ? 'Joining...' : 'Join Session',
                        icon: _isJoining ? null : Icons.videocam_outlined,
                        onTap: (canJoin && !_isJoining) ? () => _joinSession(session) : null,
                      ),
                    ),
                    if (!canJoin) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Join is enabled when the session is approved and within 15 minutes before it starts until it ends.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (canCancel)
                      SizedBox(
                        width: double.infinity,
                        child: ZelpSecondaryButton(
                          label: _isCanceling ? 'Cancelling...' : 'Cancel Session',
                          icon: _isCanceling ? null : Icons.cancel_outlined,
                          onTap: _isCanceling ? null : () => _cancelSession(session),
                        ),
                      ),
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
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
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
