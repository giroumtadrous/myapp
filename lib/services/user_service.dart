import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';

/// Service for fetching and managing user profile data from Firestore.
class UserService {
  static const String _usersCollection = 'users';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetches the user profile for the given [uid].
  /// Returns [AppUser] if the document exists, null otherwise.
  Future<AppUser?> getUser(String uid) async {
    final doc = await _firestore.collection(_usersCollection).doc(uid).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return AppUser.fromFirestore(doc);
  }

  /// Stream of the user profile for the given [uid].
  Stream<AppUser?> userStream(String uid) {
    return _firestore
        .collection(_usersCollection)
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return AppUser.fromFirestore(doc);
    });
  }

  /// Creates or overwrites the user document in Firestore.
  Future<void> createUser(AppUser user) async {
    await _firestore
        .collection(_usersCollection)
        .doc(user.id)
        .set(user.toFirestore());
  }
}
