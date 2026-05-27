import 'package:flutter/material.dart';

import '../../models/category_model.dart';
import '../../models/subject_model.dart';
import '../../models/tutor_model.dart';
import '../../repositories/category_repository.dart';
import '../../repositories/subject_repository.dart';
import '../../repositories/tutors_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_transitions.dart';
import '../../widgets/zelp_ui_components.dart';
import '../booking/zelp_tutor_profile_screen.dart';

class ZelpExploreScreen extends StatefulWidget {
  const ZelpExploreScreen({super.key});

  @override
  State<ZelpExploreScreen> createState() => _ZelpExploreScreenState();
}

class _ZelpExploreScreenState extends State<ZelpExploreScreen> {
  final CategoryRepository _categoryRepository = CategoryRepository();
  final SubjectRepository _subjectRepository = SubjectRepository();
  final TutorsRepository _tutorsRepository = TutorsRepository();

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
      final subjectMatch = _selectedSubject == null ||
          tutor.subjects.contains(_selectedSubject!) ||
          (selectedSubjectName != null &&
              tutor.subjects.any(
                (subject) => subject.toLowerCase() == selectedSubjectName.toLowerCase(),
              ));

      final subjectText = tutor.subjects
          .map((subjectId) => subjectNameById[subjectId] ?? subjectId)
          .join(' ')
          .toLowerCase();

      final searchMatch = query.isEmpty ||
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

  Widget _buildTutorResults({
    required BuildContext context,
    required Stream<List<Tutor>> tutorStream,
    required Map<String, String> subjectNameById,
  }) {
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
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Something went wrong loading tutors.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          );
        }

        final tutors = tutorSnapshot.data ?? [];
        final filteredTutors = _applySearchAndSort(tutors, subjectNameById);

        if (filteredTutors.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No matching tutors found.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            mainAxisExtent: 260,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: filteredTutors.length,
          itemBuilder: (context, index) {
            final tutor = filteredTutors[index];
            final names = tutor.name.split(' ');
            final initials = names.map((n) => n.isNotEmpty ? n[0] : '').take(2).join();

            return ZelpTutorCard(
              data: ZelpTutorCardData(
                photoLabel: initials.isNotEmpty ? initials : 'TR',
                name: tutor.name,
                subject: tutor.subjects.isNotEmpty ? tutor.subjects.first : 'Tutor',
                rating: tutor.rating.toStringAsFixed(1),
                description: tutor.bio,
                price: '\$${tutor.hourlyRate.toStringAsFixed(0)}/hr',
                availability: 'Available today',
              ),
              onTap: () {
                Navigator.of(context).push(
                  AppTransitions.slideFromRight(
                    page: ZelpTutorProfileScreen(tutor: tutor),
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
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Discover Tutors')),
      body: SafeArea(
        child: StreamBuilder<List<Subject>>(
          stream: _subjectRepository.fetchSubjects(),
          builder: (context, allSubjectsSnapshot) {
            final allSubjects = allSubjectsSnapshot.data ?? const <Subject>[];
            final subjectNameById = {
              for (final subject in allSubjects) subject.id: subject.name,
            };

            return StreamBuilder<List<Category>>(
              stream: _categoryRepository.fetchCategories(),
              builder: (context, categorySnapshot) {
                final categories = categorySnapshot.data ?? const <Category>[];
                final categoryNames = ['All', ...categories.map((c) => c.name)];
                
                int activeIndex = 0;
                if (_selectedCategory != 'all') {
                  final idx = categories.indexWhere((c) => c.id == _selectedCategory);
                  if (idx != -1) activeIndex = idx + 1;
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: ZelpSearchBar(
                        hintText: 'Search tutors or subjects',
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                    ),
                    
                    // Sort Options Row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<_TutorSortOption>(
                              initialValue: _sortOption,
                              dropdownColor: AppTheme.surface,
                              decoration: const InputDecoration(
                                labelText: 'Sort by',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: _TutorSortOption.highestRating,
                                  child: Text('Highest Rating'),
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

                    // Categories Horizontal Scroll List
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: ZelpCategoryTabs(
                        items: categoryNames,
                        selectedIndex: activeIndex,
                        onChanged: (index) {
                          setState(() {
                            if (index == 0) {
                              _selectedCategory = 'all';
                            } else {
                              _selectedCategory = categories[index - 1].id;
                            }
                            _selectedSubject = null;
                          });
                        },
                      ),
                    ),

                    // Selected Subject Sub-filters
                    if (_selectedCategory != 'all')
                      StreamBuilder<List<Subject>>(
                        stream: _subjectRepository.fetchSubjectsByCategory(_selectedCategory),
                        builder: (context, categorySubjectsSnapshot) {
                          final categorySubjects = categorySubjectsSnapshot.data ?? const <Subject>[];
                          if (categorySubjects.isEmpty) return const SizedBox.shrink();

                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: categorySubjects.map((subject) {
                                final isSelected = _selectedSubject == subject.id;
                                return FilterChip(
                                  label: Text(subject.name),
                                  selected: isSelected,
                                  backgroundColor: AppTheme.surface,
                                  selectedColor: AppTheme.primary.withValues(alpha: 0.16),
                                  side: BorderSide(color: AppTheme.border().color),
                                  onSelected: (_) {
                                    setState(() {
                                      _selectedSubject = isSelected ? null : subject.id;
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),

                    // Results
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          if (_selectedCategory == 'all') {
                            return _buildTutorResults(
                              context: context,
                              tutorStream: _tutorsRepository.getTutors(),
                              subjectNameById: subjectNameById,
                            );
                          } else {
                            return StreamBuilder<List<Subject>>(
                              stream: _subjectRepository.fetchSubjectsByCategory(_selectedCategory),
                              builder: (context, categorySubjectsSnapshot) {
                                final categorySubjects = categorySubjectsSnapshot.data ?? const <Subject>[];
                                final categorySubjectTokens = categorySubjects
                                    .expand((subject) => [subject.id, subject.name])
                                    .map((value) => value.trim())
                                    .where((value) => value.isNotEmpty)
                                    .toSet()
                                    .toList();

                                final tutorStream = _selectedSubject != null
                                    ? _tutorsRepository.getTutorsByAnySubjects([
                                        _selectedSubject!,
                                        subjectNameById[_selectedSubject!] ?? '',
                                      ])
                                    : _tutorsRepository.getTutorsByAnySubjects(categorySubjectTokens);

                                return _buildTutorResults(
                                  context: context,
                                  tutorStream: tutorStream,
                                  subjectNameById: subjectNameById,
                                );
                              },
                            );
                          }
                        },
                      ),
                    ),
                  ],
                );
              },
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
