import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/session_model.dart';
import '../../models/tutor_model.dart';
import '../../repositories/session_repository.dart';
import '../../repositories/tutors_repository.dart';
import '../../services/jitsi_meet_service.dart';
import '../../services/user_service.dart';
import '../../widgets/category_chip.dart';
import '../../models/subject_categories.dart';
import '../../widgets/search_bar_widget.dart';
import '../../widgets/session_card.dart';
import '../../widgets/tutor_card.dart';
import '../booking/session_details_screen.dart';
import '../booking/tutor_booking_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _userService = UserService();
  final _tutorsRepository = TutorsRepository();
  final _sessionRepository = SessionRepository();

  final _categories = const [
    (id: 'all', label: 'All', icon: Icons.grid_view_rounded),
    (id: 'math', label: 'Mathematics', icon: Icons.calculate_outlined),
    (id: 'physics', label: 'Physics', icon: Icons.science_outlined),
    (id: 'cs', label: 'Computer Science', icon: Icons.computer),
  ];

  int _selectedCategoryIndex = 0;
  String? _selectedSubject;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    // log the current mapping of subjects grouped by their "main" categories.
    // this satisfies the request to "print the subjects" categorized by main.
    _tutorsRepository.getSubjectsGroupedByMain().listen((map) {
      debugPrint('=== subjects grouped by main ===');
      map.forEach((main, subjects) {
        debugPrint('$main -> $subjects');
      });
    });
  }

  /// compute unique, sorted list of subjects from a list of tutors.
  /// Optionally restrict to the provided [mainCategory]; when null (or
  /// "all") the full set of subjects from the tutors is returned.  This
  /// ensures that only math subjects show up when the math category is shown,
  /// physics subjects when physics is selected, etc.
  List<String> _subjectsForTutors(List<Tutor> tutors, String? mainCategory) {
    final set = <String>{};
    for (final t in tutors) {
      set.addAll(t.subjects);
    }
    if (mainCategory != null && mainCategory != 'all') {
      // filter out any subject not belonging to the chosen main category
      final allowed = SubjectCategories.subjectsForMain(mainCategory);
      set.removeWhere((s) => !allowed.contains(s));
    }
    final subjects = set.toList()..sort();
    return subjects;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final selectedCategoryId = _categories[_selectedCategoryIndex].id;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(userService: _userService),
                  const SizedBox(height: 24),
                  SearchBarWidget(
                    hintText: 'Search tutors by name',
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.trim().toLowerCase();
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Find a tutor',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text('See all'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final label = _categories[index].label;
                        final icon = _categories[index].icon;
                        return CategoryChip(
                          label: label,
                          icon: icon,
                          isSelected: index == _selectedCategoryIndex,
                          onTap: () {
                            setState(() {
                              _selectedCategoryIndex = index;
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  // when a category is selected we also want to surface the
                  // subjects that fall under that main area.  the tutors stream
                  // already filters by `main`, so we can compute the unique
                  // subjects directly from the returned tutors.
                  StreamBuilder<List<Tutor>>(
                    stream: _tutorsRepository.getTutors(
                      categoryFilter: selectedCategoryId == 'all'
                          ? null
                          : selectedCategoryId,
                      subjectFilter: _selectedSubject,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const _TutorsLoadingState();
                      }

                      if (snapshot.hasError) {
                        return _TutorsErrorState(
                          message:
                              snapshot.error?.toString() ??
                              'Something went wrong',
                        );
                      }

                      final tutors = snapshot.data ?? [];
                      final filteredTutors = _searchQuery.isEmpty
                          ? tutors
                          : tutors
                                .where(
                                  (tutor) => tutor.name.toLowerCase().contains(
                                    _searchQuery,
                                  ),
                                )
                                .toList();
                      final subjects = _subjectsForTutors(
                        filteredTutors,
                        selectedCategoryId == 'all' ? null : selectedCategoryId,
                      );

                      // log subjects so they are printed whenever the stream
                      // updates, fulfilling the "print the subjects" requirement
                      if (subjects.isNotEmpty) {
                        debugPrint(
                          'Subjects for $selectedCategoryId: $subjects',
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (subjects.isNotEmpty) ...[
                            Text(
                              'Subjects',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: subjects.map((s) {
                                final selected = _selectedSubject == s;
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (selected) {
                                        _selectedSubject = null;
                                      } else {
                                        _selectedSubject = s;
                                      }
                                    });
                                  },
                                  child: Chip(
                                    label: Text(s),
                                    backgroundColor: selected
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.primary.withOpacity(0.1)
                                        : null,
                                    side: selected
                                        ? BorderSide(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          )
                                        : null,
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 24),
                          ],
                          if (_selectedSubject != null) ...[
                            Row(
                              children: [
                                Text(
                                  'Filter: $_selectedSubject',
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedSubject = null;
                                    });
                                  },
                                  child: const Text('Clear'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                          Text(
                            'Recommended tutors',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (filteredTutors.isEmpty)
                            _TutorsEmptyState(
                              categoryFilter: selectedCategoryId == 'all'
                                  ? null
                                  : selectedCategoryId,
                            )
                          else
                            SizedBox(
                              height: 230,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: filteredTutors.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  final tutor = filteredTutors[index];
                                  // compute per-tutor visible subjects for the
                                  // currently selected category. Prefer DB
                                  // provided mapping, fallback to local filter.
                                  final visible = tutor.subjectsByMain != null
                                      ? tutor.subjectsByMain![selectedCategoryId] ??
                                            []
                                      : tutor.subjects
                                            .where(
                                              (s) =>
                                                  SubjectCategories.subjectsForMain(
                                                    selectedCategoryId,
                                                  ).contains(s),
                                            )
                                            .toList();

                                  return TutorCard(
                                    tutor: tutor,
                                    visibleSubjects: visible.isEmpty
                                        ? null
                                        : visible,
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              TutorBookingScreen(tutor: tutor),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Upcoming sessions',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _UpcomingSessionsList(sessionRepository: _sessionRepository),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UpcomingSessionsList extends StatelessWidget {
  final SessionRepository sessionRepository;

  const _UpcomingSessionsList({required this.sessionRepository});

  String _meetingDisplayName(User user) {
    final displayName = (user.displayName ?? '').trim();
    if (displayName.isNotEmpty) return displayName;

    final email = (user.email ?? '').trim();
    if (email.isNotEmpty) return email.split('@').first;

    return 'Student';
  }

  Future<void> _startMeeting(
    BuildContext context,
    SessionModel session,
    User user,
  ) async {
    try {
      final roomName = await sessionRepository.ensureSessionRoomName(
        session.id,
        existingRoomName: session.roomName,
      );

      await JitsiMeetService.instance.startMeeting(
        roomName: roomName,
        userName: _meetingDisplayName(user),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not join session: $e')));
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'booked':
      case 'confirmed':
        return Colors.green[600]!;
      case 'pending_payment_verification':
        return Colors.orange[700]!;
      case 'payment_rejected':
        return Colors.red[700]!;
      default:
        return Colors.blueGrey;
    }
  }

  Future<void> _confirmCancel(
    BuildContext context,
    SessionModel session,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Session'),
        content: const Text('Are you sure you want to cancel this session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await sessionRepository.cancelSession(session.id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Session cancelled.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Text('Sign in to see your sessions.');
    }

    return StreamBuilder<List<SessionModel>>(
      stream: sessionRepository.upcomingSessions(currentUser.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final sessions = snapshot.data ?? [];
        if (sessions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No upcoming sessions yet. Book a tutor to get started.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
          );
        }
        return Column(
          children: sessions.map((s) {
            final dateStr = DateFormat.yMMMd().format(s.dateTime);
            final timeStr = DateFormat.jm().format(s.dateTime);
            final isSessionConfirmed = s.status == 'confirmed';
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SessionCard(
                tutorName: s.tutorName ?? s.tutorId,
                subject: s.subject,
                date: dateStr,
                timeRange: timeStr,
                statusLabel: s.status,
                statusColor: _statusColor(s.status),
                isActive: false,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SessionDetailsScreen(sessionId: s.id),
                    ),
                  );
                },
                onJoinMeet: isSessionConfirmed
                    ? () => _startMeeting(context, s, currentUser)
                    : null,
                onCancel: () => _confirmCancel(context, s),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _TutorsLoadingState extends StatelessWidget {
  const _TutorsLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _TutorsErrorState extends StatelessWidget {
  final String message;

  const _TutorsErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Something went wrong',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorsEmptyState extends StatelessWidget {
  final String? categoryFilter;

  const _TutorsEmptyState({this.categoryFilter});

  @override
  Widget build(BuildContext context) {
    final hasFilter = categoryFilter != null && categoryFilter!.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              hasFilter
                  ? 'No tutors in $categoryFilter'
                  : 'No tutors available',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              hasFilter
                  ? 'Try another category or check back later.'
                  : 'Check back later or try a different category.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final UserService userService;

  const _Header({required this.userService});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final currentUser = FirebaseAuth.instance.currentUser;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
            child: Icon(Icons.person, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FutureBuilder(
              future: currentUser != null
                  ? userService.getUser(currentUser.uid)
                  : null,
              builder: (context, snapshot) {
                final name = snapshot.data?.name.isNotEmpty == true
                    ? snapshot.data!.name
                    : (currentUser?.displayName?.isNotEmpty == true
                          ? currentUser!.displayName!
                          : currentUser?.email ?? 'User');
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome Back,',
                      style: textTheme.bodySmall?.copyWith(
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: IconButton(
              onPressed: () {},
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          ),
        ],
      ),
    );
  }
}
