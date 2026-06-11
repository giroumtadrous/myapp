import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../repositories/reviews_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_loading_indicator.dart';

class ReviewScreen extends StatefulWidget {
  final String sessionId;

  const ReviewScreen({super.key, required this.sessionId});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _reviewsRepository = ReviewsRepository();
  final _commentController = TextEditingController();

  int _rating = 0;
  bool _submitting = false;
  bool _alreadyReviewed = false;
  bool _loading = true;

  String _tutorId = '';
  String _tutorName = '';
  String _subject = '';

  @override
  void initState() {
    super.initState();
    _loadSessionData();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadSessionData() async {
    try {
      // Check if already reviewed
      final hasReview =
          await _reviewsRepository.hasReviewForSession(widget.sessionId);
      if (hasReview) {
        if (!mounted) return;
        setState(() {
          _alreadyReviewed = true;
          _loading = false;
        });
        return;
      }

      // Load session data
      final sessionDoc =
          await _firestore.collection('sessions').doc(widget.sessionId).get();
      if (!sessionDoc.exists) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      final data = sessionDoc.data()!;
      _tutorId = (data['tutorId'] ?? '').toString();
      _subject = (data['subject'] ?? '').toString();

      // Load tutor name
      if (_tutorId.isNotEmpty) {
        final tutorDoc =
            await _firestore.collection('tutors').doc(_tutorId).get();
        if (tutorDoc.exists) {
          _tutorName = (tutorDoc.data()?['name'] ?? 'Unknown Tutor').toString();
        }
      }

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _submitReview() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating.')),
      );
      return;
    }

    final studentId = FirebaseAuth.instance.currentUser?.uid;
    if (studentId == null) return;

    setState(() => _submitting = true);

    try {
      await _reviewsRepository.submitReview(
        sessionId: widget.sessionId,
        tutorId: _tutorId,
        studentId: studentId,
        rating: _rating.toDouble(),
        reviewText: _commentController.text.trim(),
      );

      // Update tutor's average rating
      final stats = await _reviewsRepository.getTutorReviewStats(_tutorId);
      await _firestore.collection('tutors').doc(_tutorId).update({
        'rating': stats.averageRating,
        'totalReviews': stats.totalReviews,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Review submitted. Thank you! ⭐'),
          backgroundColor: AppTheme.primary,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(title: const Text('Rate Your Session')),
      body: _loading
          ? const AppLoadingIndicator(message: 'Loading session...')
          : _alreadyReviewed
              ? _buildAlreadyReviewed(isDark)
              : _buildReviewForm(isDark),
    );
  }

  Widget _buildAlreadyReviewed(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: AppTheme.primary,
                size: 44,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Already Reviewed',
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
              'You have already submitted a review for this session.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewForm(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Tutor Info Card ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.fromBorderSide(AppTheme.border(isDark: isDark)),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: AppTheme.buttonGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _tutorName.isNotEmpty
                          ? _tutorName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: isDark
                            ? AppTheme.darkBackground
                            : AppTheme.lightBackground,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _tutorName.isNotEmpty ? _tutorName : 'Tutor',
                  style: TextStyle(
                    color: isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.lightTextPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _subject,
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Star Rating ──
          Text(
            'How would you rate this session?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark
                  ? AppTheme.darkTextPrimary
                  : AppTheme.lightTextPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starIndex = index + 1;
              return GestureDetector(
                onTap: () => setState(() => _rating = starIndex),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: AnimatedScale(
                    scale: _rating >= starIndex ? 1.15 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      _rating >= starIndex
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: _rating >= starIndex
                          ? AppTheme.primary
                          : (isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.lightTextSecondary),
                      size: 44,
                    ),
                  ),
                ),
              );
            }),
          ),
          if (_rating > 0) ...[
            const SizedBox(height: 8),
            Text(
              _ratingLabel(_rating),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 24),

          // ── Comment TextField ──
          TextField(
            controller: _commentController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Share your experience... (optional)',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 28),

          // ── Submit Button ──
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submitReview,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Submit Review',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _ratingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent!';
      default:
        return '';
    }
  }
}
