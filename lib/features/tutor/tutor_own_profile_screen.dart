import 'package:flutter/material.dart';

import '../../models/tutor_model.dart';
import '../../repositories/tutors_repository.dart';

/// The profile screen shown to the currently logged-in tutor.
/// Displays their own name, photo, bio, subjects, and rating.
/// Allows editing and saving the bio to Firestore.
class TutorOwnProfileScreen extends StatefulWidget {
  /// The Firestore document ID for this tutor (e.g. "tutor_001").
  final String tutorId;

  const TutorOwnProfileScreen({
    super.key,
    required this.tutorId,
  });

  @override
  State<TutorOwnProfileScreen> createState() => _TutorOwnProfileScreenState();
}

class _TutorOwnProfileScreenState extends State<TutorOwnProfileScreen> {
  final TutorsRepository _repo = TutorsRepository();
  final TextEditingController _bioController = TextEditingController();

  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  /// Persists the edited bio to Firestore, then exits editing mode.
  Future<void> _saveBio() async {
    final newBio = _bioController.text.trim();
    setState(() => _isSaving = true);
    try {
      await _repo.updateTutorBio(widget.tutorId, newBio);
      if (!mounted) return;
      setState(() {
        _isEditing = false;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bio updated successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save bio: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  /// Cancels editing and restores the controller to the last saved bio.
  void _cancelEdit(String currentBio) {
    _bioController.text = currentBio;
    setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: StreamBuilder<Tutor?>(
        stream: _repo.getTutorById(widget.tutorId),
        builder: (context, snapshot) {
          // ── Loading ───────────────────────────────────────────────────────
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // ── Error / not found ─────────────────────────────────────────────
          if (snapshot.hasError || snapshot.data == null) {
            final colorScheme = Theme.of(context).colorScheme;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 52, color: colorScheme.error),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load your profile.',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    if (snapshot.hasError) ...[
                      const SizedBox(height: 8),
                      Text(
                        snapshot.error.toString(),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            );
          }

          // ── Profile ───────────────────────────────────────────────────────
          final tutor = snapshot.data!;
          final textTheme = Theme.of(context).textTheme;
          final colorScheme = Theme.of(context).colorScheme;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Avatar ───────────────────────────────────────────────
                  Center(
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor: colorScheme.primary.withOpacity(0.12),
                      child: Icon(
                        Icons.person,
                        size: 52,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Name ─────────────────────────────────────────────────
                  Center(
                    child: Text(
                      tutor.name,
                      style: textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (tutor.email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        tutor.email,
                        style: textTheme.bodyMedium
                            ?.copyWith(color: Colors.grey[600]),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // ── Rating & hourly rate ──────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star_rounded,
                          size: 20, color: Colors.amber[600]),
                      const SizedBox(width: 4),
                      Text(
                        tutor.rating.toStringAsFixed(1),
                        style: textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 20),
                      Icon(Icons.attach_money,
                          size: 18, color: colorScheme.primary),
                      Text(
                        '${tutor.hourlyRate.toStringAsFixed(0)}/hr',
                        style: textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),
                  const Divider(),
                  const SizedBox(height: 20),

                  // ── Subjects ─────────────────────────────────────────────
                  _SectionLabel(label: 'Subjects Taught'),
                  const SizedBox(height: 10),
                  if (tutor.subjects.isEmpty)
                    Text(
                      'No subjects listed yet.',
                      style: textTheme.bodyMedium
                          ?.copyWith(color: Colors.grey[500]),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: tutor.subjects
                          .map(
                            (s) => Chip(
                              label: Text(s),
                              backgroundColor:
                                  colorScheme.primary.withOpacity(0.08),
                              labelStyle: TextStyle(
                                color: colorScheme.primary,
                                fontSize: 13,
                              ),
                              side: BorderSide.none,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 0),
                            ),
                          )
                          .toList(),
                    ),

                  const SizedBox(height: 28),

                  // ── Bio ──────────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _SectionLabel(label: 'Bio'),
                      if (!_isEditing)
                        TextButton.icon(
                          onPressed: () {
                            _bioController.text = tutor.bio;
                            setState(() => _isEditing = true);
                          },
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Edit'),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_isEditing) ...[
                    // ── Bio edit field ──────────────────────────────────────
                    TextField(
                      controller: _bioController,
                      maxLines: 5,
                      maxLength: 500,
                      enabled: !_isSaving,
                      decoration: InputDecoration(
                        hintText: 'Tell students about yourself…',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest
                            .withOpacity(0.3),
                        counterStyle:
                            textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Save / Cancel buttons ─────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed:
                              _isSaving ? null : () => _cancelEdit(tutor.bio),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _isSaving ? null : _saveBio,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_outlined, size: 18),
                          label: Text(_isSaving ? 'Saving…' : 'Save'),
                        ),
                      ],
                    ),
                  ] else ...[
                    // ── Bio display ─────────────────────────────────────────
                    Text(
                      tutor.bio.isEmpty
                          ? 'No bio yet. Tap "Edit" to add one.'
                          : tutor.bio,
                      style: textTheme.bodyMedium?.copyWith(
                        color: tutor.bio.isEmpty ? Colors.grey[500] : null,
                        height: 1.6,
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Helper widget ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}
