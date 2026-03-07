import 'subject_categories.dart';

class Tutor {
  final String id;
  final String name;
  final String email;
  final String bio;
  final List<String> subjects;
  final List<String> main;
  final Map<String, List<String>>? subjectsByMain;
  final double hourlyRate;
  final double rating;
  final Map<String, List<String>> weeklyAvailability;

  Tutor({
    required this.id,
    required this.name,
    required this.email,
    required this.bio,
    required this.hourlyRate,
    required this.rating,
    required this.subjects,
    required this.main,
    required this.weeklyAvailability,
    this.subjectsByMain,
  });

  factory Tutor.fromMap(String id, Map<String, dynamic> data) {
    return Tutor(
      id: id,
      name: _toString(data['name']),
      email: _toString(data['email']),
      bio: _toString(data['bio']),
      hourlyRate: _toDouble(data['hourlyRate'] ?? data['hourly_rate']),
      rating: _toDouble(data['rating']),
      subjects: _toSubjects(data['subjects']),
      // if the document didn't explicitly supply mains, try to infer them
      // from the subjects list using our predefined mappings.
      main: _inferMain(_toSubjects(data['main']), _toSubjects(data['subjects'])),
      subjectsByMain: _toSubjectsByMain(data['subjects_by_main']),
      weeklyAvailability: _toWeeklyAvailability(
        data['weeklyAvailability'] ?? data['weekly_availability'],
      ),
    );
  }

  static String _toString(dynamic v) =>
      v != null ? v.toString().trim() : '';

  static List<String> _toSubjects(dynamic v) {
    if (v == null) return [];
    if (v is List) {
      return v.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    }
    return [];
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'bio': bio,
      'hourlyRate': hourlyRate,
      'rating': rating,
      'subjects': subjects,
      'main': main,
      'subjects_by_main': subjectsByMain,
      'weeklyAvailability': weeklyAvailability,
    };
  }

  /// helper used by the factory to ensure `main` is non-null and not empty
  /// by falling back to an inferred value if necessary.
  static List<String> _inferMain(List<String> original, List<String> subjects) {
    if (original.isNotEmpty) return original;
    return _infer(subjects);
  }

  static List<String> _infer(List<String> subjects) {
    return SubjectCategories.inferMainsFromSubjects(subjects);
  }

  static Map<String, List<String>>? _toSubjectsByMain(dynamic v) {
    if (v == null) return null;
    if (v is Map) {
      final Map<String, List<String>> result = {};
      v.forEach((key, value) {
        if (value is List) {
          result[key.toString()] = value.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
        }
      });
      return result;
    }
    return null;
  }
  
  static Map<String, List<String>> _toWeeklyAvailability(dynamic v) {
    if (v == null || v is! Map) return {};

    final result = <String, List<String>>{};
    v.forEach((key, value) {
      if (value is List) {
        result[key.toString().toLowerCase()] = List<String>.from(
          value.map((e) => e.toString()),
        );
      }
    });
    return result;
  }
}