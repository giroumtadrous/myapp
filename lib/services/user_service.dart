import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';

/// Service for managing user profile data and FCM tokens in Firestore.
class UserService {
  static const String _usersCollection = 'users';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

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

  /// Saves or updates a user document with FCM token and additional fields.
  /// Uses merge: true to avoid overwriting existing data.
  Future<void> saveUserWithFCM({
    required String uid,
    required String name,
    required String email,
    required String role,
    String? institution,
  }) async {
    try {
      // Get FCM token
      final fcmToken = await _getFCMToken();
      
      debugPrint('[UserService] Saving user $uid with FCM token: ${fcmToken?.substring(0, 20)}...');

      final userData = {
        'uid': uid,
        'name': name,
        'email': email,
        'role': role,
        'institution': institution,
        'fcmToken': fcmToken,
        'fcmTokens': FieldValue.arrayUnion([if (fcmToken != null) fcmToken]),
        'fcmPlatform': defaultTargetPlatform.name,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Only add createdAt if this is a new document
      final existingDoc = await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .get();
      
      if (!existingDoc.exists) {
        userData['createdAt'] = FieldValue.serverTimestamp();
        debugPrint('[UserService] Creating new user document for $uid');
      } else {
        debugPrint('[UserService] Updating existing user document for $uid');
      }

      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .set(userData, SetOptions(merge: true));

      debugPrint('[UserService] User document saved successfully for $uid');
    } catch (e, st) {
      debugPrint('[UserService] Error saving user: $e');
      debugPrint(st.toString());
      rethrow;
    }
  }

  /// Updates FCM token for an existing user.
  Future<void> updateFCMToken(String uid) async {
    try {
      final fcmToken = await _getFCMToken();
      
      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint('[UserService] FCM token is empty, skipping update for $uid');
        return;
      }

      debugPrint('[UserService] Updating FCM token for $uid: ${fcmToken.substring(0, 20)}...');

      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .set({
        'fcmToken': fcmToken,
        'fcmTokens': FieldValue.arrayUnion([fcmToken]),
        'fcmPlatform': defaultTargetPlatform.name,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('[UserService] FCM token updated successfully for $uid');
    } catch (e, st) {
      debugPrint('[UserService] Error updating FCM token: $e');
      debugPrint(st.toString());
      rethrow;
    }
  }

  /// Gets the current FCM token for the device.
  /// Returns null if token cannot be retrieved.
  Future<String?> _getFCMToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        debugPrint('[UserService] FCM token retrieved: ${token.substring(0, 20)}...');
        return token;
      } else {
        debugPrint('[UserService] FCM token is null or empty');
        return null;
      }
    } catch (e) {
      debugPrint('[UserService] Error getting FCM token: $e');
      return null;
    }
  }

  /// Gets the FCM token for debugging purposes.
  Future<String?> getFCMToken() async {
    return await _getFCMToken();
  }
}
