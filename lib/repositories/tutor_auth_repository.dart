import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Repository for tutor authentication and verification.
/// Links Firebase Authentication users to tutor documents via the `authUid` field.
/// Tutors keep their existing fixed IDs (e.g., tutor_001) separate from Firebase UIDs.
class TutorAuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Signs in a tutor with email and password.
  /// Verifies that the Firebase UID is linked to a tutor document via the `authUid` field.
  ///
  /// Throws [FirebaseAuthException] for auth errors.
  /// Throws [Exception] if the user is not registered as a tutor.
  Future<User> signInTutor({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('Failed to sign in.');
      }

      // Verify the user is a tutor by checking if their Firebase UID is linked
      // to a tutor document via the authUid field
      final isTutor = await _isTutorUser(user.uid);
      if (!isTutor) {
        // Sign out the user immediately if they're not a tutor
        await _auth.signOut();
        throw Exception(
          'This account is not registered as a tutor. '
          'Please contact support if you believe this is an error.',
        );
      }

      return user;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  /// Checks if a Firebase UID is linked to a tutor via the `authUid` field.
  /// Queries the tutors collection where `authUid == uid`.
  Future<bool> _isTutorUser(String uid) async {
    try {
      final query = await _firestore
          .collection('tutors')
          .where('authUid', isEqualTo: uid)
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      // Error checking tutor status - user is not a tutor
      return false;
    }
  }

  /// Retrieves the tutor document ID (e.g., "tutor_001") for the given Firebase UID.
  /// Queries the tutors collection where `authUid == uid` and returns the document ID.
  ///
  /// Returns the tutor ID if found, or null if the user is not a tutor.
  Future<String?> getTutorIdFromAuthUid(String uid) async {
    try {
      final query = await _firestore
          .collection('tutors')
          .where('authUid', isEqualTo: uid)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return query.docs.first.id;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Stream version of tutor lookup by Firebase Auth UID.
  /// Keeps role routing reactive and avoids repeated one-off reads.
  Stream<String?> watchTutorIdFromAuthUid(String uid) {
    return _firestore
        .collection('tutors')
        .where('authUid', isEqualTo: uid)
        .limit(1)
        .snapshots()
        .map((query) => query.docs.isNotEmpty ? query.docs.first.id : null);
  }

  /// Gets the current authenticated user.
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Signs out the current tutor.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Gets the current tutor's Firebase UID.
  String? getCurrentAuthUid() {
    return _auth.currentUser?.uid;
  }

  /// Verifies if the current user is a tutor without signing them in.
  /// Useful for checking permissions.
  Future<bool> isCurrentUserTutor() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    return _isTutorUser(user.uid);
  }

  /// Gets the tutor document ID for the currently authenticated user.
  /// Returns null if the user is not authenticated or not a tutor.
  Future<String?> getCurrentTutorId() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return getTutorIdFromAuthUid(uid);
  }
}
