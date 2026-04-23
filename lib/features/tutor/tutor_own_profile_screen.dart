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
      backgroundColor: const Color(0xFFF6F6F8),
      appBar: AppBar(title: const Text('Tutor Profile')),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Mirrors tutor profile card structure from design/tutorprofile.html.
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 60,
                                backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
                                child: Icon(
                                  Icons.person,
                                  size: 64,
                                  color: colorScheme.primary,
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: FloatingActionButton.small(
                                  onPressed: () {},
                                  backgroundColor: const Color(0xFF4051B5),
                                  child: const Icon(Icons.photo_camera, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            tutor.name,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tutor.email,
                            style: const TextStyle(
                              color: Color(0xFF4051B5),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: 106,
                        child: _ProfileStatCard(
                          title: 'Rating',
                          value: tutor.rating.toStringAsFixed(1),
                          icon: Icons.star,
                        ),
                      ),
                      SizedBox(
                        width: 106,
                        child: _ProfileStatCard(
                          title: 'Reviews',
                          value: '${tutor.totalReviews}',
                          icon: Icons.rate_review_outlined,
                        ),
                      ),
                      SizedBox(
                        width: 106,
                        child: _ProfileStatCard(
                          title: 'Completed',
                          value: '${tutor.completedSessionsCount}',
                          icon: Icons.menu_book_rounded,
                        ),
                      ),
                      SizedBox(
                        width: 106,
                        child: _ProfileStatCard(
                          title: 'Rate',
                          value: '\$${tutor.hourlyRate.toStringAsFixed(0)}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SectionLabel(label: 'Institution'),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        tutor.university.trim().isEmpty
                            ? 'University not provided yet.'
                            : tutor.university,
                        style: textTheme.bodyMedium?.copyWith(
                          color: tutor.university.trim().isEmpty
                              ? Colors.grey[500]
                              : null,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

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
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: TextField(
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
                                .withValues(alpha: 0.3),
                            counterStyle:
                                textTheme.bodySmall?.copyWith(color: Colors.grey),
                          ),
                        ),
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
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          tutor.bio.isEmpty
                              ? 'No bio yet. Tap "Edit" to add one.'
                              : tutor.bio,
                          style: textTheme.bodyMedium?.copyWith(
                            color: tutor.bio.isEmpty ? Colors.grey[500] : null,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  _SectionLabel(label: 'Subjects'),
                  const SizedBox(height: 8),
                  if (tutor.subjects.isEmpty)
                    Text(
                      'No subjects listed yet.',
                      style: textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tutor.subjects
                          .map(
                            (s) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF2FF),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                s,
                                style: const TextStyle(
                                  color: Color(0xFF4051B5),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),

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

class _ProfileStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData? icon;

  const _ProfileStatCard({
    required this.title,
    required this.value,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE3EE)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              if (icon != null)
                Icon(icon, size: 16, color: const Color(0xFFF59E0B)),
            ],
          ),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
