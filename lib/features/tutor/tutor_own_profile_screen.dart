import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/tutor_model.dart';
import '../../repositories/tutors_repository.dart';
import '../../services/profile_photo_storage_service.dart';
import '../../services/theme_service.dart';
import '../../theme/app_theme.dart';

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
  bool _isUploadingPhoto = false;

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

  Future<void> _pickAndUploadPhoto() async {
    if (_isUploadingPhoto) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Select Profile Photo',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSourceOption(
                  icon: Icons.photo_library_outlined,
                  label: 'Gallery',
                  source: ImageSource.gallery,
                ),
                _buildSourceOption(
                  icon: Icons.camera_alt_outlined,
                  label: 'Camera',
                  source: ImageSource.camera,
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final pickedFile = await ProfilePhotoStorageService.instance.pickImage(source);
    if (pickedFile == null) return;

    setState(() => _isUploadingPhoto = true);

    try {
      final downloadUrl = await ProfilePhotoStorageService.instance.uploadProfilePhoto(
        image: pickedFile,
        userId: widget.tutorId,
        pathPrefix: 'tutors',
      );

      await _repo.updateTutorPhotoUrl(widget.tutorId, downloadUrl);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile photo updated successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload photo: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required ImageSource source,
  }) {
    return InkWell(
      onTap: () => Navigator.pop(context, source),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        child: Column(
          children: [
            Icon(icon, size: 36, color: AppTheme.primary),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        title: const Text('Tutor Profile'),
        backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      ),
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
                                backgroundImage: tutor.profileImageUrl != null && tutor.profileImageUrl!.isNotEmpty
                                    ? NetworkImage(tutor.profileImageUrl!)
                                    : null,
                                child: _isUploadingPhoto
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : (tutor.profileImageUrl != null && tutor.profileImageUrl!.isNotEmpty
                                        ? null
                                        : Icon(
                                            Icons.person,
                                            size: 64,
                                            color: colorScheme.primary,
                                          )),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: FloatingActionButton.small(
                                  onPressed: _pickAndUploadPhoto,
                                  backgroundColor: AppTheme.primary,
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
                              color: AppTheme.primary,
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
                              ? (isDark ? AppTheme.darkTextSecondary : Colors.grey[500])
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
                            color: tutor.bio.isEmpty
                                ? (isDark ? AppTheme.darkTextSecondary : Colors.grey[500])
                                : null,
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
                                color: AppTheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                s,
                                style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),

                  const SizedBox(height: 16),
                  _SectionLabel(label: 'Preferences'),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.brightness_4_outlined),
                      title: const Text('Dark Mode'),
                      trailing: StatefulBuilder(
                        builder: (context, setState) {
                          return Switch(
                            value: ThemeService().isDarkMode,
                            onChanged: (value) {
                              ThemeService().setDarkMode(value);
                              setState(() {});
                            },
                          );
                        },
                      ),
                    ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark 
            ? AppTheme.primary.withValues(alpha: 0.22)
            : AppTheme.primary.withValues(alpha: 0.14),
        ),
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
                Icon(icon, size: 16, color: AppTheme.primary),
            ],
          ),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
