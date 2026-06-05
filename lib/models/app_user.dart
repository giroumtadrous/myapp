import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a user profile stored in Firestore.
class AppUser {
  final String id;
  final String name;
  final String email;
  final DateTime createdAt;
  final String role;
  final String institution;
  final String universityOrHighSchool;
  final String photoUrl;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.createdAt,
    this.role = 'student',
    this.institution = '',
    this.universityOrHighSchool = '',
    this.photoUrl = '',
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw FormatException('User document is empty');
    }
    final createdAt = data['createdAt'];
    return AppUser(
      id: doc.id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      createdAt: createdAt is Timestamp
          ? createdAt.toDate()
          : DateTime.now(),
      role: (data['role'] ?? 'student').toString(),
      institution: (data['institution'] ?? data['school'] ?? '').toString(),
      universityOrHighSchool:
          (data['universityOrHighSchool'] ??
                  data['institution'] ??
                  data['school'] ??
                  '')
               .toString(),
      photoUrl: (data['photoUrl'] ?? data['profileImageUrl'] ?? data['photoURL'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'email': email,
        'createdAt': Timestamp.fromDate(createdAt),
        'role': role,
        'institution': institution,
        'universityOrHighSchool': universityOrHighSchool,
        'photoUrl': photoUrl,
      };
}
