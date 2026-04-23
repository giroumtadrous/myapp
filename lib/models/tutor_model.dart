class Tutor {
  final String id;
  final String name;
  final String email;
  final String bio;
  final String university;
  final String? profileImageUrl;
  final List<String> subjects;
  final List<String> main;
  final Map<String, List<String>>? subjectsByMain;
  final double hourlyRate;
  final double rating;
  final int totalReviews;
  final int completedSessionsCount;
  final Map<String, List<String>> weeklyAvailability;

  Tutor({
    required this.id,
    required this.name,
    required this.email,
    required this.bio,
    required this.university,
    this.profileImageUrl,
    required this.hourlyRate,
    required this.rating,
    required this.totalReviews,
    required this.completedSessionsCount,
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
      university: _toString(
        data['university'] ??
            data['universityOrHighSchool'] ??
            data['institution'] ??
            data['school'],
      ),
      profileImageUrl: _toOptionalString(
        data['profileImageUrl'] ??
        data['photoUrl'] ??
        data['photoURL'] ??
        data['avatarUrl'],
      ),
      hourlyRate: _toDouble(data['hourlyRate'] ?? data['hourly_rate']),
      rating: _toDouble(data['rating']),
      totalReviews: _toInt(data['totalReviews']),
      completedSessionsCount: _toInt(data['completedSessionsCount']),
      subjects: _toSubjects(data['subjects']),
      main: _toSubjects(data['main']),
      subjectsByMain: _toSubjectsByMain(data['subjects_by_main']),
      weeklyAvailability: _toWeeklyAvailability(
        data['weeklyAvailability'] ?? data['weekly_availability'],
      ),
    );
  }

  static String _toString(dynamic v) =>
      v != null ? v.toString().trim() : '';

  static String? _toOptionalString(dynamic v) {
    if (v == null) return null;
    final value = v.toString().trim();
    return value.isEmpty ? null : value;
  }

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

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'bio': bio,
      'university': university,
      'profileImageUrl': profileImageUrl,
      'hourlyRate': hourlyRate,
      'rating': rating,
      'totalReviews': totalReviews,
      'completedSessionsCount': completedSessionsCount,
      'subjects': subjects,
      'main': main,
      'subjects_by_main': subjectsByMain,
      'weeklyAvailability': weeklyAvailability,
    };
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

  Tutor copyWith({
    double? rating,
    int? totalReviews,
    int? completedSessionsCount,
    String? university,
  }) {
    return Tutor(
      id: id,
      name: name,
      email: email,
      bio: bio,
      university: university ?? this.university,
      profileImageUrl: profileImageUrl,
      hourlyRate: hourlyRate,
      rating: rating ?? this.rating,
      totalReviews: totalReviews ?? this.totalReviews,
      completedSessionsCount:
          completedSessionsCount ?? this.completedSessionsCount,
      subjects: subjects,
      main: main,
      weeklyAvailability: weeklyAvailability,
      subjectsByMain: subjectsByMain,
    );
  }
}