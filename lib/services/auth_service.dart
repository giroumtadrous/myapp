import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _usernameClaimsCollection = 'usernameClaims';

  static final RegExp _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  // iOS setup notes:
  // 1) Enable "Sign in with Apple" capability in Xcode Runner target.
  // 2) Add CFBundleURLTypes for Google Sign-In reversed client ID in ios/Runner/Info.plist:
  //    <key>CFBundleURLTypes</key>
  //    <array>
  //      <dict>
  //        <key>CFBundleURLSchemes</key>
  //        <array>
  //          <string>com.googleusercontent.apps.YOUR_REVERSED_CLIENT_ID</string>
  //        </array>
  //      </dict>
  //    </array>
  // 3) Enable Apple provider in Firebase Console -> Authentication -> Sign-in providers.
  //
  // Android setup notes:
  // - Add SHA-1 fingerprint in Firebase Console for Google Sign-In.
  // - Download updated google-services.json after adding SHA-1.

  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        provider.setCustomParameters({'prompt': 'select_account'});
        return await _auth.signInWithPopup(provider);
      }

      if (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS &&
          defaultTargetPlatform != TargetPlatform.macOS) {
        throw UnsupportedError(
          'Google sign-in is not supported on this platform. Use Android, iOS, macOS, or Web.',
        );
      }

      final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

      // Clear cached selection so Google shows the account picker reliably.
      try {
        await googleSignIn.disconnect();
      } catch (_) {
        await googleSignIn.signOut();
      }

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('[AuthService] Google sign-in cancelled by user.');
        return null;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e, st) {
      debugPrint(
        '[AuthService] Firebase Google sign-in failed: ${e.code} ${e.message}',
      );
      debugPrint(st.toString());
      rethrow;
    } on UnsupportedError catch (e, st) {
      debugPrint('[AuthService] Google sign-in unsupported: $e');
      debugPrint(st.toString());
      rethrow;
    } catch (e, st) {
      debugPrint('[AuthService] Google sign-in failed: $e');
      debugPrint(st.toString());
      rethrow;
    }
  }

  Future<UserCredential?> signInWithApple() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      debugPrint('[AuthService] Apple sign-in is only available on iOS.');
      return null;
    }

    try {
      final rawNonce = _generateNonce();
      final hashedNonce = _sha256OfString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final oauthCredential = OAuthProvider(
        'apple.com',
      ).credential(idToken: appleCredential.identityToken, rawNonce: rawNonce);

      return await _auth.signInWithCredential(oauthCredential);
    } catch (e, st) {
      final text = e.toString().toLowerCase();
      if (text.contains('canceled') || text.contains('cancelled')) {
        debugPrint('[AuthService] Apple sign-in cancelled by user.');
        return null;
      }

      debugPrint('[AuthService] Apple sign-in failed: $e');
      debugPrint(st.toString());
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e, st) {
      debugPrint('[AuthService] Failed to send password reset email: $e');
      debugPrint(st.toString());
      rethrow;
    }
  }

  Future<bool> isUsernameAvailable(
    String username, {
    String? excludeUid,
  }) async {
    final normalized = username.trim().toLowerCase();
    if (normalized.isEmpty) return false;

    final doc = await _firestore
        .collection(_usernameClaimsCollection)
        .doc(normalized)
        .get();

    if (!doc.exists) return true;

    final ownerUid = (doc.data()?['uid'] ?? '').toString().trim();
    if (ownerUid.isEmpty) return false;
    if (excludeUid == null) return false;

    return ownerUid == excludeUid;
  }

  Future<void> saveUserProfileWithUsernameClaim({
    required String uid,
    required String username,
    required String name,
    required String institution,
    required String email,
    required String role,
    required String authProvider,
    String? displayName,
    String? photoUrl,
  }) async {
    final normalizedUsername = normalizeUsername(username);
    final userRef = _firestore.collection('users').doc(uid);
    final usernameRef = _firestore
        .collection(_usernameClaimsCollection)
        .doc(normalizedUsername);

    await _firestore.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      final claimSnap = await tx.get(usernameRef);

      final claimOwnerUid = (claimSnap.data()?['uid'] ?? '').toString().trim();
      if (claimSnap.exists && claimOwnerUid != uid) {
        throw StateError('That username is already taken.');
      }

      final existingData = userSnap.data() ?? <String, dynamic>{};
      final existingUsername = (existingData['username'] ?? '')
          .toString()
          .trim();
      if (existingUsername.isNotEmpty &&
          existingUsername != normalizedUsername) {
        final oldUsernameRef = _firestore
            .collection(_usernameClaimsCollection)
            .doc(existingUsername);
        final oldClaimSnap = await tx.get(oldUsernameRef);
        final oldClaimOwnerUid = (oldClaimSnap.data()?['uid'] ?? '')
            .toString()
            .trim();
        if (oldClaimSnap.exists && oldClaimOwnerUid == uid) {
          tx.delete(oldUsernameRef);
        }
      }

      final claimData = <String, dynamic>{
        'uid': uid,
        'username': normalizedUsername,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (!claimSnap.exists) {
        claimData['createdAt'] = FieldValue.serverTimestamp();
      }
      tx.set(usernameRef, claimData, SetOptions(merge: true));

      final payload = <String, dynamic>{
        'uid': uid,
        'username': normalizedUsername,
        'name': name,
        'institution': institution,
        'universityOrHighSchool': institution,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'role': role,
        'authProvider': authProvider,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!userSnap.exists) {
        payload['createdAt'] = FieldValue.serverTimestamp();
      }

      tx.set(userRef, payload, SetOptions(merge: true));
    });
  }

  bool isValidEmail(String email) {
    return _emailRegex.hasMatch(email.trim());
  }

  String normalizeUsername(String username) {
    return username.trim().toLowerCase();
  }

  Future<bool> isProfileComplete(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return false;
      final data = doc.data() ?? <String, dynamic>{};
      // Require both username and institution
      final username = (data['username'] ?? '').toString().trim();
      final institution =
          (data['universityOrHighSchool'] ?? data['institution'] ?? '')
              .toString()
              .trim();
      return username.isNotEmpty && institution.isNotEmpty;
    } catch (e, st) {
      debugPrint('[AuthService] Failed to check profile completeness: $e');
      debugPrint(st.toString());
      return false;
    }
  }

  Stream<bool> watchProfileComplete(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return false;
          final data = doc.data()!;
          final username = (data['username'] ?? '').toString().trim();
          final institution =
              (data['universityOrHighSchool'] ?? data['institution'] ?? '')
                  .toString()
                  .trim();
          return username.isNotEmpty && institution.isNotEmpty;
        });
  }

  Future<bool> autoCreateSocialProfile(User user, String authProvider) async {
    try {
      final uid = user.uid;
      final doc = await _firestore.collection('users').doc(uid).get();

      // If profile already exists, don't overwrite
      if (doc.exists) {
        debugPrint('[AuthService] Profile already exists for user $uid');
        return true;
      }

      // Generate username from displayName or email
      String username = '';
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        username = user.displayName!
            .replaceAll(RegExp(r'\s+'), '')
            .toLowerCase();
      } else if (user.email != null && user.email!.isNotEmpty) {
        username = user.email!.split('@')[0].toLowerCase();
      } else {
        username = 'user_${uid.substring(0, 8)}';
      }

      // Ensure username is valid (at least 3 chars)
      if (username.length < 3) {
        username = '${username}_user';
      }

      username = normalizeUsername(username);

      await saveUserProfileWithUsernameClaim(
        uid: uid,
        username: username,
        name: user.displayName ?? username,
        institution: '',
        email: user.email ?? '',
        role: 'student',
        authProvider: authProvider,
        displayName: user.displayName ?? '',
        photoUrl: user.photoURL ?? '',
      );

      debugPrint(
        '[AuthService] Auto-created profile for user $uid with username: $username',
      );
      return true;
    } catch (e, st) {
      debugPrint('[AuthService] Failed to auto-create social profile: $e');
      debugPrint(st.toString());
      return false;
    }
  }

  bool isSocialProviderUser(User user) {
    final providers = user.providerData.map((p) => p.providerId).toSet();
    return providers.contains('google.com') || providers.contains('apple.com');
  }

  String detectSocialProvider(User user) {
    final providers = user.providerData.map((p) => p.providerId).toSet();
    if (providers.contains('apple.com')) return 'apple';
    if (providers.contains('google.com')) return 'google';
    return 'unknown';
  }

  String _generateNonce([int length = 32]) {
    const chars =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  String _sha256OfString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
