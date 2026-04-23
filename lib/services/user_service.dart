import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';

/// Service for managing user profile data and FCM tokens in Firestore.
class UserService {
  static const String _usersCollection = 'users';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  StreamSubscription<String>? _tokenRefreshSub;

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
        'universityOrHighSchool': institution ?? '',
        'fcmToken': fcmToken,
        'fcmTokens': FieldValue.arrayUnion(
          fcmToken != null ? <String>[fcmToken] : <String>[],
        ),
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
    await syncFcmToken(uid);
  }

  /// Syncs current FCM token to Firestore and keeps it updated on refresh.
  Future<void> syncFcmToken(String userId) async {
    try {
      final token = await _messaging.getToken();
      if (token == null || token.trim().isEmpty) {
        debugPrint('[FCM] Token is null/empty for user $userId');
      } else {
        await _firestore.collection(_usersCollection).doc(userId).set({
          'fcmToken': token,
          'fcmTokens': FieldValue.arrayUnion([token]),
          'fcmPlatform': defaultTargetPlatform.name,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('[FCM] Token synced for user $userId (${token.substring(0, 20)}...)');
      }

      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _messaging.onTokenRefresh.listen((refreshedToken) async {
        if (refreshedToken.trim().isEmpty) {
          debugPrint('[FCM] Refreshed token is empty for user $userId');
          return;
        }

        try {
          await _firestore.collection(_usersCollection).doc(userId).set({
            'fcmToken': refreshedToken,
            'fcmTokens': FieldValue.arrayUnion([refreshedToken]),
            'fcmPlatform': defaultTargetPlatform.name,
            'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          debugPrint('[FCM] Refreshed token synced for user $userId');
        } catch (e, st) {
          debugPrint('[FCM] Failed to sync refreshed token for $userId: $e');
          debugPrint(st.toString());
        }
      });
    } catch (e, st) {
      debugPrint('[FCM] Failed to sync token for $userId: $e');
      debugPrint(st.toString());
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
