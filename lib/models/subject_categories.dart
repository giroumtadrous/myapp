/// Defines known main categories and the subjects that belong to each one.
///
/// This allows the app to infer a tutor's "main" categories based on the
/// list of subjects they teach.  The tutor documents in Firestore still
/// include an explicit `main` field, but we can compute it automatically
/// during reading or when creating new tutors.

class SubjectCategories {
  static const List<String> math = [
    'Algebra',
    'Calculus I — Derivatives',
    'Calculus II',
    'Geometry',
    'Statistics',
    // add other math-specific subjects here
  ];

  static const List<String> physics = [
    'Physics — Kinematics Review',
    'Physics — Optics',
    'Physics — Electromagnetism',
    // etc.
  ];

  static const List<String> cs = [
    'Computer Science — Programming',
    'Computer Science — Data Structures',
    'Computer Science — Algorithms',
    // etc.
  ];

  /// Returns the ids of the categories whose subject list intersects
  /// with [subjects].  For example if [subjects] contains a math topic
  /// and a cs topic, both 'math' and 'cs' will be returned.
  static List<String> inferMainsFromSubjects(List<String> subjects) {
    final Set<String> mains = {};
    for (final subject in subjects) {
      if (math.contains(subject)) mains.add('math');
      if (physics.contains(subject)) mains.add('physics');
      if (cs.contains(subject)) mains.add('cs');
    }
    return mains.toList();
  }

  /// Return the list of defined subjects for a given main category id.
  ///
  /// Calling code can use this to restrict displayed subjects to the current
  /// section (e.g. only show math subjects when the "math" category is
  /// selected).
  static List<String> subjectsForMain(String main) {
    switch (main) {
      case 'math':
        return math;
      case 'physics':
        return physics;
      case 'cs':
        return cs;
      default:
        return [];
    }
  }
}
