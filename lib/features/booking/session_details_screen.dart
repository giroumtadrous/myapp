import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/session_model.dart';
import '../../repositories/session_repository.dart';
import '../../services/jitsi_meet_service.dart';
import '../../utils/meeting_utils.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/pressable_scale.dart';

class SessionDetailsScreen extends StatefulWidget {
  final String sessionId;

  const SessionDetailsScreen({super.key, required this.sessionId});

  @override
  State<SessionDetailsScreen> createState() => _SessionDetailsScreenState();
}

class _SessionDetailsScreenState extends State<SessionDetailsScreen> {
  final SessionRepository _sessionRepository = SessionRepository();
  bool _isCanceling = false;
  bool _isJoining = false;

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
      final roomName = await _sessionRepository.ensureSessionRoomName(
        session.id,
        existingRoomName: session.roomName,
      );

      await JitsiMeetService.instance.startMeeting(
        roomName: roomName,
        userName: resolveMeetingDisplayName(user),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Session Details')),
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
          final canJoin = _sessionRepository.canJoinSession(session);
          final canCancel = _canCancel(session);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ExpandableSectionCard(
                title: session.subject,
                initiallyExpanded: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LabeledValue(
                      label: 'Status',
                      value: _titleCase(session.status),
                    ),
                    _LabeledValue(
                      label: 'Date',
                      value: DateFormat.yMMMMd().format(session.dateTime),
                    ),
                    _LabeledValue(
                      label: 'Time',
                      value: DateFormat.jm().format(session.dateTime),
                    ),
                    _LabeledValue(
                      label: 'Duration',
                      value: '${session.durationMinutes} min',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tutor Information',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _PersonTile(
                      name: details.tutor.name,
                      photoUrl: details.tutor.photoUrl,
                      fallbackIcon: Icons.school_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                child: _LabeledValue(
                  label: 'Student Name',
                  value: details.student.name,
                ),
              ),
              const SizedBox(height: 12),
              _ExpandableSectionCard(
                title: 'Notes',
                child: Text(
                  session.notes.trim().isEmpty
                      ? 'No notes added for this session.'
                      : session.notes,
                ),
              ),
              const SizedBox(height: 12),
              _ExpandableSectionCard(
                title: 'Documents',
                child: session.documents.isEmpty
                    ? const Text('No documents uploaded.')
                    : Column(
                        children: session.documents
                            .map(
                              (doc) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.description_outlined),
                                title: Text(doc.name),
                                subtitle: Text(doc.type ?? 'Document'),
                                trailing: const Icon(Icons.open_in_new),
                                onTap: () => _openDocument(doc),
                              ),
                            )
                            .toList(),
                      ),
              ),
              const SizedBox(height: 16),
              if (canJoin)
                SizedBox(
                  width: double.infinity,
                  child: PressableScale(
                    child: FilledButton.icon(
                      onPressed: _isJoining
                          ? null
                          : () => _joinSession(session),
                      icon: _isJoining
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.video_call_outlined),
                      label: Text(_isJoining ? 'Joining...' : 'Join Session'),
                    ),
                  ),
                ),
              if (!canJoin)
                Text(
                  'Join button appears when the session is approved and close to start time.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              const SizedBox(height: 8),
              if (canCancel)
                SizedBox(
                  width: double.infinity,
                  child: PressableScale(
                    child: OutlinedButton.icon(
                      onPressed: _isCanceling
                          ? null
                          : () => _cancelSession(session),
                      icon: _isCanceling
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cancel_outlined),
                      label: Text(
                        _isCanceling ? 'Cancelling...' : 'Cancel Session',
                      ),
                    ),
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
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }
}

class _ExpandableSectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final bool initiallyExpanded;

  const _ExpandableSectionCard({
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          title: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledValue extends StatelessWidget {
  final String label;
  final String value;

  const _LabeledValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(child: Text(value)),
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
