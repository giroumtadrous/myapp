import 'package:flutter/material.dart';

import '../../models/category_model.dart';
import '../../models/subject_model.dart';
import '../../models/tutor_model.dart';
import '../../repositories/category_repository.dart';
import '../../repositories/subject_repository.dart';
import '../../repositories/tutors_repository.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/search_bar_widget.dart';
import '../../widgets/tutor_card.dart';
import '../booking/tutor_booking_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _categoryRepository = CategoryRepository();
  final _subjectRepository = SubjectRepository();
  final _tutorsRepository = TutorsRepository();

  String _searchQuery = '';
  String _selectedCategory = 'all';
  String? _selectedSubject;
  _TutorSortOption _sortOption = _TutorSortOption.highestRating;

  List<Tutor> _applySearchAndSort(
    List<Tutor> tutors,
    Map<String, String> subjectNameById,
  ) {
    final query = _searchQuery.trim().toLowerCase();
    final selectedSubjectName = _selectedSubject != null
        ? subjectNameById[_selectedSubject!]
        : null;

    final filtered = tutors.where((tutor) {
      final subjectMatch =
          _selectedSubject == null ||
          tutor.subjects.contains(_selectedSubject!) ||
          (selectedSubjectName != null &&
              tutor.subjects.any(
                (subject) =>
                    subject.toLowerCase() == selectedSubjectName.toLowerCase(),
              ));

      final subjectText = tutor.subjects
          .map((subjectId) => subjectNameById[subjectId] ?? subjectId)
          .join(' ')
          .toLowerCase();

      final searchMatch =
          query.isEmpty ||
          tutor.name.toLowerCase().contains(query) ||
          subjectText.contains(query);

      return subjectMatch && searchMatch;
    }).toList();

    switch (_sortOption) {
      case _TutorSortOption.highestRating:
        filtered.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case _TutorSortOption.nameAsc:
        filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case _TutorSortOption.nameDesc:
        filtered.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
    }

    return filtered;
  }

  IconData _iconForCategory(String id) {
    switch (id.toLowerCase()) {
      case 'math':
        return Icons.calculate_outlined;
      case 'physics':
        return Icons.science_outlined;
      case 'cs':
      case 'computer_science':
      case 'computer-science':
        return Icons.computer;
      default:
        return Icons.category_outlined;
    }
  }

  Widget _buildTutorResults({
    required BuildContext context,
    required Stream<List<Tutor>> tutorStream,
    required Map<String, String> subjectNameById,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return StreamBuilder<List<Tutor>>(
      stream: tutorStream,
      builder: (context, tutorSnapshot) {
        if (tutorSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (tutorSnapshot.hasError) {
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
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final tutors = tutorSnapshot.data ?? [];
        final filteredTutors = _applySearchAndSort(tutors, subjectNameById);

        if (filteredTutors.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No matching tutors',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Try a different search, filter, or sort combination.',
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: filteredTutors.length,
          separatorBuilder: (_, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final tutor = filteredTutors[index];
            final visibleSubjects = tutor.subjects
                .map((subjectId) => subjectNameById[subjectId] ?? subjectId)
                .toList();

            return TutorCard(
              tutor: tutor,
              visibleSubjects: visibleSubjects,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TutorBookingScreen(tutor: tutor),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Explore')),
      body: SafeArea(
        child: StreamBuilder<List<Subject>>(
          stream: _subjectRepository.fetchSubjects(),
          builder: (context, allSubjectsSnapshot) {
            final allSubjects = allSubjectsSnapshot.data ?? const <Subject>[];
            final subjectNameById = {
              for (final subject in allSubjects) subject.id: subject.name,
            };

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: SearchBarWidget(
                    hintText: 'Search by tutor name or subject',
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.trim().toLowerCase();
                      });
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<_TutorSortOption>(
                          initialValue: _sortOption,
                          decoration: const InputDecoration(
                            labelText: 'Sort',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: _TutorSortOption.highestRating,
                              child: Text('Highest rating'),
                            ),
                            DropdownMenuItem(
                              value: _TutorSortOption.nameAsc,
                              child: Text('Name (A-Z)'),
                            ),
                            DropdownMenuItem(
                              value: _TutorSortOption.nameDesc,
                              child: Text('Name (Z-A)'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _sortOption = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                StreamBuilder<List<Category>>(
                  stream: _categoryRepository.fetchCategories(),
                  builder: (context, categorySnapshot) {
                    final categories = categorySnapshot.data ?? const <Category>[];
                    final hasSelectedCategory =
                        _selectedCategory == 'all' ||
                        categories.any((category) => category.id == _selectedCategory);

                    if (!hasSelectedCategory) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        setState(() {
                          _selectedCategory = 'all';
                          _selectedSubject = null;
                        });
                      });
                    }

                    return Expanded(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 52,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                              scrollDirection: Axis.horizontal,
                              itemCount: categories.length + 1,
                              separatorBuilder: (_, index) => const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  return CategoryChip(
                                    label: 'All',
                                    icon: Icons.grid_view_rounded,
                                    isSelected: _selectedCategory == 'all',
                                    onTap: () {
                                      setState(() {
                                        _selectedCategory = 'all';
                                        _selectedSubject = null;
                                      });
                                    },
                                  );
                                }

                                final category = categories[index - 1];
                                return CategoryChip(
                                  label: category.name,
                                  icon: _iconForCategory(category.id),
                                  isSelected: _selectedCategory == category.id,
                                  onTap: () {
                                    setState(() {
                                      _selectedCategory = category.id;
                                      _selectedSubject = null;
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                          if (_selectedCategory == 'all')
                            Expanded(
                              child: _buildTutorResults(
                                context: context,
                                tutorStream: _tutorsRepository.getTutors(),
                                subjectNameById: subjectNameById,
                              ),
                            )
                          else
                            Expanded(
                              child: StreamBuilder<List<Subject>>(
                                stream: _subjectRepository.fetchSubjectsByCategory(
                                  _selectedCategory,
                                ),
                                builder: (context, categorySubjectsSnapshot) {
                                  if (categorySubjectsSnapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(24),
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }

                                  final categorySubjects =
                                      categorySubjectsSnapshot.data ?? const <Subject>[];
                                  final categorySubjectIds = categorySubjects
                                      .map((subject) => subject.id)
                                      .where((id) => id.isNotEmpty)
                                      .toList();
                                    final categorySubjectTokens = categorySubjects
                                      .expand((subject) => [subject.id, subject.name])
                                      .map((value) => value.trim())
                                      .where((value) => value.isNotEmpty)
                                      .toSet()
                                      .toList();

                                  if (_selectedSubject != null &&
                                      !categorySubjectIds.contains(_selectedSubject)) {
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      if (!mounted) return;
                                      setState(() {
                                        _selectedSubject = null;
                                      });
                                    });
                                  }

                                  final tutorStream = _selectedSubject != null
                                      ? _tutorsRepository.getTutorsByAnySubjects([
                                          _selectedSubject!,
                                          subjectNameById[_selectedSubject!] ?? '',
                                        ])
                                      : _tutorsRepository.getTutorsByAnySubjects(
                                          categorySubjectTokens,
                                        );

                                  return Column(
                                    children: [
                                      if (categorySubjects.isNotEmpty)
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            12,
                                            16,
                                            0,
                                          ),
                                          child: Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: categorySubjects.map((subject) {
                                              final isSelected =
                                                  _selectedSubject == subject.id;
                                              return FilterChip(
                                                label: Text(subject.name),
                                                selected: isSelected,
                                                onSelected: (_) {
                                                  setState(() {
                                                    _selectedSubject =
                                                        isSelected ? null : subject.id;
                                                  });
                                                },
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      if (_selectedSubject != null)
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: Padding(
                                            padding: const EdgeInsets.only(right: 16),
                                            child: TextButton(
                                              onPressed: () {
                                                setState(() {
                                                  _selectedSubject = null;
                                                });
                                              },
                                              child: const Text('Clear subject'),
                                            ),
                                          ),
                                        ),
                                      Expanded(
                                        child: _buildTutorResults(
                                          context: context,
                                          tutorStream: tutorStream,
                                          subjectNameById: subjectNameById,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

enum _TutorSortOption {
  highestRating,
  nameAsc,
  nameDesc,
}
