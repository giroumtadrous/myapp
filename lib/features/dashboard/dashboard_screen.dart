import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/tutor_model.dart';
import '../../repositories/tutors_repository.dart';
import '../../services/user_service.dart';
import '../../widgets/category_chip.dart';
import '../../models/subject_categories.dart';
import '../../widgets/search_bar_widget.dart';
import '../../widgets/session_card.dart';
import '../../widgets/tutor_card.dart';
import '../booking/tutor_booking_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _userService = UserService();
  final _tutorsRepository = TutorsRepository();

  final _categories = const [
    (id: 'all', label: 'All', icon: Icons.grid_view_rounded),
    (id: 'math', label: 'Mathematics', icon: Icons.calculate_outlined),
    (id: 'physics', label: 'Physics', icon: Icons.science_outlined),
    (id: 'cs', label: 'Computer Science', icon: Icons.computer),
  ];

  int _selectedCategoryIndex = 0;
  String? _selectedSubject;

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
                  const SearchBarWidget(hintText: 'Search subjects or tutors'),
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
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
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
                      final subjects = _subjectsForTutors(tutors, selectedCategoryId == 'all' ? null : selectedCategoryId);

                      // log subjects so they are printed whenever the stream
                      // updates, fulfilling the "print the subjects" requirement
                      if (subjects.isNotEmpty) {
                        debugPrint(
                            'Subjects for $selectedCategoryId: $subjects');
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
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withOpacity(0.1)
                                        : null,
                                    side: selected
                                        ? BorderSide(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary)
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
                                  style: textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
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
                          if (tutors.isEmpty)
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
                                itemCount: tutors.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  final tutor = tutors[index];
                                  // compute per-tutor visible subjects for the
                                  // currently selected category. Prefer DB
                                  // provided mapping, fallback to local filter.
                                  final visible = tutor.subjectsByMain != null
                                      ? tutor.subjectsByMain![selectedCategoryId] ?? []
                                      : tutor.subjects.where((s) =>
                                          SubjectCategories.subjectsForMain(selectedCategoryId).contains(s)).toList();

                                  return TutorCard(
                                    tutor: tutor,
                                    visibleSubjects: visible.isEmpty ? null : visible,
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
                  SessionCard(
                    tutorName: 'Sarah Lee',
                    subject: 'Calculus I — Derivatives',
                    date: 'Today',
                    timeRange: '10:00 – 11:00 AM',
                    statusLabel: 'Confirmed',
                    statusColor: Colors.green[600]!,
                    isActive: true,
                  ),
                  const SizedBox(height: 12),
                  SessionCard(
                    tutorName: 'James Miller',
                    subject: 'Physics — Kinematics Review',
                    date: 'Tomorrow',
                    timeRange: '2:00 – 3:00 PM',
                    statusLabel: 'Scheduled',
                    statusColor: Colors.orange[700]!,
                    isActive: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
