import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/student_progress_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_loading_indicator.dart';

class StudentProgressScreen extends StatefulWidget {
  const StudentProgressScreen({super.key});

  @override
  State<StudentProgressScreen> createState() => _StudentProgressScreenState();
}

class _StudentProgressScreenState extends State<StudentProgressScreen> {
  final _firestore = FirebaseFirestore.instance;

  String get _studentId => FirebaseAuth.instance.currentUser?.uid ?? '';

  Stream<List<StudentProgress>> _progressStream() {
    if (_studentId.isEmpty) return Stream.value([]);
    return _firestore
        .collection('students')
        .doc(_studentId)
        .collection('progress')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => StudentProgress.fromFirestore(doc))
            .toList());
  }

  Stream<List<Map<String, dynamic>>> _completedSessionsStream() {
    if (_studentId.isEmpty) return Stream.value([]);
    return _firestore
        .collection('sessions')
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .asyncMap((snap) async {
      final sessions = snap.docs.where((doc) {
        final data = doc.data();
        final sId = (data['studentId'] ?? '').toString();
        final sIds = data['studentIds'];
        if (sId == _studentId) return true;
        if (sIds is List && sIds.contains(_studentId)) return true;
        return false;
      }).toList();

      sessions.sort((a, b) {
        final aDate = _parseDate(a.data());
        final bDate = _parseDate(b.data());
        return bDate.compareTo(aDate);
      });

      // Enrich with tutor names
      final tutorIds =
          sessions.map((d) => (d.data()['tutorId'] ?? '').toString()).toSet();
      final tutorNames = <String, String>{};
      for (final id in tutorIds) {
        if (id.isEmpty) continue;
        try {
          final tutorDoc = await _firestore.collection('tutors').doc(id).get();
          tutorNames[id] = (tutorDoc.data()?['name'] ?? 'Unknown Tutor').toString();
        } catch (_) {
          tutorNames[id] = 'Unknown Tutor';
        }
      }

      return sessions.map((doc) {
        final data = doc.data();
        final tutorId = (data['tutorId'] ?? '').toString();
        return {
          'id': doc.id,
          'subject': (data['subject'] ?? '').toString(),
          'tutorName': tutorNames[tutorId] ?? 'Unknown Tutor',
          'dateTime': _parseDate(data),
          'durationMinutes':
              (data['durationMinutes'] as num?)?.toInt() ?? 60,
          'status': (data['status'] ?? '').toString(),
        };
      }).toList();
    });
  }

  DateTime _parseDate(Map<String, dynamic> data) {
    final raw = data['dateTime'] ?? data['date'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
    return DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_studentId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view progress.')),
      );
    }

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(title: const Text('My Progress')),
      body: StreamBuilder<List<StudentProgress>>(
        stream: _progressStream(),
        builder: (context, progressSnap) {
          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: _completedSessionsStream(),
            builder: (context, sessionsSnap) {
              if (progressSnap.connectionState == ConnectionState.waiting &&
                  sessionsSnap.connectionState == ConnectionState.waiting) {
                return const AppLoadingIndicator(
                    message: 'Loading your progress...');
              }

              final progressList = progressSnap.data ?? [];
              final sessions = sessionsSnap.data ?? [];

              final totalSessions = progressList.fold<int>(
                  0, (sum, p) => sum + p.totalSessions);
              final totalMinutes = progressList.fold<int>(
                  0, (sum, p) => sum + p.totalMinutes);
              final subjectsCount = progressList.length;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Stats Row ──
                  Row(
                    children: [
                      _StatCard(
                        icon: Icons.school_outlined,
                        value: '$totalSessions',
                        label: 'Sessions',
                        color: AppTheme.primary,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 10),
                      _StatCard(
                        icon: Icons.timer_outlined,
                        value: '${(totalMinutes / 60).toStringAsFixed(1)}',
                        label: 'Hours',
                        color: const Color(0xFF3B82F6),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 10),
                      _StatCard(
                        icon: Icons.menu_book_outlined,
                        value: '$subjectsCount',
                        label: 'Subjects',
                        color: const Color(0xFFF59E0B),
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── By Subject ──
                  Text(
                    'By Subject',
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
                    'Your learning breakdown per subject',
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (progressList.isEmpty)
                    _EmptyCard(
                      message:
                          'No progress yet. Complete your first session to see stats here!',
                      isDark: isDark,
                    )
                  else
                    ...progressList.map(
                        (p) => _SubjectCard(progress: p, isDark: isDark)),

                  const SizedBox(height: 24),

                  // ── Session History ──
                  Text(
                    'Session History',
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.lightTextPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (sessions.isEmpty)
                    _EmptyCard(
                      message: 'No completed sessions yet.',
                      isDark: isDark,
                    )
                  else
                    ...sessions.map((s) => _SessionHistoryTile(
                          session: s,
                          isDark: isDark,
                        )),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ── Stat Card ───────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.fromBorderSide(AppTheme.border(isDark: isDark)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Subject Card ────────────────────────────────────────────────────────────
class _SubjectCard extends StatelessWidget {
  final StudentProgress progress;
  final bool isDark;

  const _SubjectCard({required this.progress, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.fromBorderSide(AppTheme.border(isDark: isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  progress.subject,
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const Spacer(),
              if (progress.lastSessionAt != null)
                Text(
                  DateFormat.MMMd().format(progress.lastSessionAt!),
                  style: TextStyle(
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MiniStat(
                icon: Icons.school_outlined,
                text: '${progress.totalSessions} sessions',
                isDark: isDark,
              ),
              const SizedBox(width: 16),
              _MiniStat(
                icon: Icons.timer_outlined,
                text: '${progress.totalHours.toStringAsFixed(1)} hrs',
                isDark: isDark,
              ),
              const SizedBox(width: 16),
              _MiniStat(
                icon: Icons.people_outline,
                text: '${progress.tutorsUsed.length} tutors',
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (progress.totalSessions / 20).clamp(0.0, 1.0),
              backgroundColor: isDark
                  ? AppTheme.primary.withValues(alpha: 0.1)
                  : AppTheme.primary.withValues(alpha: 0.08),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppTheme.primary),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDark;

  const _MiniStat({
    required this.icon,
    required this.text,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: isDark
              ? AppTheme.darkTextSecondary
              : AppTheme.lightTextSecondary,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: isDark
                ? AppTheme.darkTextSecondary
                : AppTheme.lightTextSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── Session History Tile ────────────────────────────────────────────────────
class _SessionHistoryTile extends StatelessWidget {
  final Map<String, dynamic> session;
  final bool isDark;

  const _SessionHistoryTile({required this.session, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final dateTime = session['dateTime'] as DateTime;
    final duration = session['durationMinutes'] as int;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.fromBorderSide(AppTheme.border(isDark: isDark)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${dateTime.day}',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  DateFormat.MMM().format(dateTime),
                  style: TextStyle(
                    color: AppTheme.primary.withValues(alpha: 0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session['subject'] as String,
                  style: TextStyle(
                    color: isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.lightTextPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  session['tutorName'] as String,
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                DateFormat.jm().format(dateTime),
                style: TextStyle(
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${duration}min',
                style: TextStyle(
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Empty Card ──────────────────────────────────────────────────────────────
class _EmptyCard extends StatelessWidget {
  final String message;
  final bool isDark;

  const _EmptyCard({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.fromBorderSide(AppTheme.border(isDark: isDark)),
      ),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDark
                ? AppTheme.darkTextSecondary
                : AppTheme.lightTextSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
