import 'package:flutter/material.dart';

import '../../models/tutor_model.dart';
import '../../repositories/tutors_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_transitions.dart';
import '../../widgets/zelp_ui_components.dart';
import 'zelp_tutor_profile_screen.dart';

class UniversityTutorsScreen extends StatefulWidget {
  final String universityName;

  const UniversityTutorsScreen({super.key, required this.universityName});

  @override
  State<UniversityTutorsScreen> createState() => _UniversityTutorsScreenState();
}

class _UniversityTutorsScreenState extends State<UniversityTutorsScreen> {
  final TutorsRepository _tutorsRepository = TutorsRepository();
  
  String _searchQuery = '';
  int _categoryIndex = 0;
  final List<String> _categories = const ['All', 'Math', 'Physics', 'Writing', 'Coding'];
  _SortOption _sortOption = _SortOption.highestRating;

  bool _tutorMatchesCategory(Tutor tutor, String categoryName) {
    if (categoryName == 'All') return true;
    final cat = categoryName.toLowerCase();
    
    // 1. Check main categories
    if (tutor.main.any((m) => m.toLowerCase() == cat || m.toLowerCase().contains(cat) || cat.contains(m.toLowerCase()))) {
      return true;
    }
    
    // 2. Check subjects
    if (tutor.subjects.any((s) => s.toLowerCase() == cat || s.toLowerCase().contains(cat) || cat.contains(s.toLowerCase()))) {
      return true;
    }
    
    // 3. Synonym matching
    if (cat == 'math') {
      final keywords = ['math', 'calc', 'algebra', 'geometry', 'trig', 'arithmetic', 'stats', 'statistics', 'maths'];
      return tutor.subjects.any((s) => keywords.any((k) => s.toLowerCase().contains(k))) ||
             tutor.main.any((m) => keywords.any((k) => m.toLowerCase().contains(k)));
    } else if (cat == 'physics') {
      final keywords = ['physics', 'phys', 'mechanic', 'thermodynamic', 'optics', 'electromagnet'];
      return tutor.subjects.any((s) => keywords.any((k) => s.toLowerCase().contains(k))) ||
             tutor.main.any((m) => keywords.any((k) => m.toLowerCase().contains(k)));
    } else if (cat == 'writing') {
      final keywords = ['writing', 'write', 'essay', 'english', 'literature', 'grammar', 'composition'];
      return tutor.subjects.any((s) => keywords.any((k) => s.toLowerCase().contains(k))) ||
             tutor.main.any((m) => keywords.any((k) => m.toLowerCase().contains(k)));
    } else if (cat == 'coding') {
      final keywords = ['coding', 'code', 'python', 'java', 'c++', 'javascript', 'html', 'css', 'programming', 'computer', 'software', 'develop'];
      return tutor.subjects.any((s) => keywords.any((k) => s.toLowerCase().contains(k))) ||
             tutor.main.any((m) => keywords.any((k) => m.toLowerCase().contains(k)));
    }
    
    return false;
  }

  List<Tutor> _applyFiltersAndSort(List<Tutor> tutors) {
    final query = _searchQuery.trim().toLowerCase();
    final category = _categories[_categoryIndex];
    final studentInstitution = widget.universityName.trim().toLowerCase();

    // 1. Filter by university
    var filtered = tutors.where((tutor) {
      return tutor.university.trim().toLowerCase() == studentInstitution;
    }).toList();

    // 2. Filter by category
    if (category != 'All') {
      filtered = filtered.where((tutor) => _tutorMatchesCategory(tutor, category)).toList();
    }

    // 3. Filter by search query
    if (query.isNotEmpty) {
      filtered = filtered.where((tutor) {
        return tutor.name.toLowerCase().contains(query) ||
               tutor.bio.toLowerCase().contains(query) ||
               tutor.subjects.any((s) => s.toLowerCase().contains(query));
      }).toList();
    }

    // 4. Sort
    switch (_sortOption) {
      case _SortOption.highestRating:
        filtered.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case _SortOption.nameAsc:
        filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case _SortOption.nameDesc:
        filtered.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          widget.universityName.isNotEmpty
              ? 'Tutors at ${widget.universityName}'
              : 'University Tutors',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
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

            // Sort Selector Row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: DropdownButtonFormField<_SortOption>(
                initialValue: _sortOption,
                dropdownColor: AppTheme.surface,
                decoration: const InputDecoration(
                  labelText: 'Sort by',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(
                    value: _SortOption.highestRating,
                    child: Text('Highest Rating'),
                  ),
                  DropdownMenuItem(
                    value: _SortOption.nameAsc,
                    child: Text('Name (A-Z)'),
                  ),
                  DropdownMenuItem(
                    value: _SortOption.nameDesc,
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

            // Categories Tabs
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: ZelpCategoryTabs(
                items: _categories,
                selectedIndex: _categoryIndex,
                onChanged: (index) {
                  setState(() {
                    _categoryIndex = index;
                  });
                },
              ),
            ),

            const SizedBox(height: 12),

            // Tutor Grid
            Expanded(
              child: StreamBuilder<List<Tutor>>(
                stream: _tutorsRepository.getTutors(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Failed to load tutors.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    );
                  }

                  final tutors = snapshot.data ?? [];
                  final filteredTutors = _applyFiltersAndSort(tutors);

                  if (filteredTutors.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No tutors found matching your criteria.',
                          style: TextStyle(color: AppTheme.textSecondary),
                          textAlign: TextAlign.center,
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
                          photoUrl: tutor.profileImageUrl ?? '',
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _SortOption {
  highestRating,
  nameAsc,
  nameDesc,
}
