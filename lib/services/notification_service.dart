import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';

const String _backgroundAndroidChannelId = 'session_updates';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    if (message.notification != null) {
      debugPrint(
        '[FCM background] ${message.notification!.title} | '
        '${message.notification!.body}',
      );
      return;
    }

    final title = message.data['title']?.toString();
    final body = message.data['body']?.toString();
    if (title == null && body == null) {
      debugPrint('[FCM background] Data-only message has no title/body.');
      return;
    }

    final plugin = FlutterLocalNotificationsPlugin();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings();
    await plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      ),
    );

    final androidPlugin = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _backgroundAndroidChannelId,
        'Session Updates',
        description: 'Notifications for booking, payment, and session updates',
        importance: Importance.high,
      ),
    );

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _backgroundAndroidChannelId,
        'Session Updates',
        channelDescription:
            'Notifications for booking, payment, and session updates',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    await plugin.show(
      message.hashCode,
      title,
      body,
      details,
      payload: message.data.isEmpty ? null : message.data.toString(),
    );

    debugPrint('[FCM background] Shown: ${title ?? ''} | ${body ?? ''}');
  } catch (e, st) {
    debugPrint('[FCM background] Failed to handle message: $e');
    debugPrint(st.toString());
  }
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String _androidChannelId = 'session_updates';
  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        _androidChannelId,
        'Session Updates',
        description: 'Notifications for booking, payment, and session updates',
        importance: Importance.high,
      );

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<User?>? _authSub;
  bool _initialized = false;
  bool _localNotificationsInitialized = false;

  String _mutePreferenceKey(String uid) => 'notifications_muted_$uid';

  Future<bool> isMutedForUser(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_mutePreferenceKey(uid)) ?? false;
  }

  Future<void> setMutedForUser({required String uid, required bool muted}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_mutePreferenceKey(uid), muted);
  }

  bool get _supportsMessaging {
    if (kIsWeb) return true;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return true;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return false;
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;

    if (!_supportsMessaging) {
      debugPrint('[FCM] Messaging not supported on this platform.');
      return;
    }

    _initialized = true;

    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await _initializeLocalNotifications();
      await _requestPermissions();
      await _configureForegroundPresentation();
      await _syncTokenForCurrentUser();
      _listenForTokenRefresh();
      _listenForAuthChanges();
      _listenForMessages();
      await _handleTerminatedMessage();
      debugPrint('[FCM] Initialization complete');
    } catch (e, st) {
      debugPrint('[FCM] Initialization error: $e');
      debugPrint(st.toString());
    }
  }

  Future<void> _requestPermissions() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final androidGranted = await androidPlugin?.requestNotificationsPermission();
      if (androidGranted != null) {
        debugPrint('[FCM] Android notification permission granted: $androidGranted');
      }
    } catch (e, st) {
      debugPrint('[FCM] Permission request failed: $e');
      debugPrint(st.toString());
    }
  }

  Future<void> _configureForegroundPresentation() async {
    try {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e, st) {
      debugPrint('[FCM] Foreground presentation setup failed: $e');
      debugPrint(st.toString());
    }
  }

  /// Re-saves the device FCM token for the signed-in user (e.g. after login).
  Future<void> syncTokenForCurrentUser() => _syncTokenForCurrentUser();

  Future<void> _syncTokenForCurrentUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      debugPrint('[FCM] Token sync skipped because user is signed out.');
      return;
    }

    try {
      final token = await _messaging.getToken();
      if (token == null || token.trim().isEmpty) {
        debugPrint('[FCM] Token is null/empty for user $uid');
        return;
      }
      debugPrint('[FCM] Retrieved token for $uid: ${token.substring(0, 10)}...');
      await _saveToken(uid: uid, token: token);
    } catch (e, st) {
      debugPrint('[FCM] Failed to sync token: $e');
      debugPrint(st.toString());
    }
  }

  void _listenForAuthChanges() {
    _authSub?.cancel();
    _authSub = _auth.authStateChanges().listen((user) async {
      if (user == null) {
        debugPrint('[FCM] Auth changed: signed out, skipping token sync.');
        return;
      }
      debugPrint('[FCM] Auth changed: signed in as ${user.uid}, syncing token.');
      await _syncTokenForCurrentUser();
    });
  }

  void _listenForTokenRefresh() {
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((token) async {
      final uid = _auth.currentUser?.uid;
      if (uid == null || token.trim().isEmpty) {
        debugPrint('[FCM] Ignored token refresh event because uid/token is invalid.');
        return;
      }

      try {
        await _saveToken(uid: uid, token: token);
      } catch (e, st) {
        debugPrint('[FCM] Failed to update refreshed token: $e');
        debugPrint(st.toString());
      }
    });
  }

  void _listenForMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      _logIncomingMessage(state: 'foreground', message: message);
      await _showForegroundNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _logIncomingMessage(state: 'opened-app', message: message);
    });
  }

  Future<void> _handleTerminatedMessage() async {
    try {
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage == null) return;

      _logIncomingMessage(state: 'terminated', message: initialMessage);
    } catch (e, st) {
      debugPrint('[FCM] Failed to process initial message: $e');
      debugPrint(st.toString());
    }
  }

  Future<void> _saveToken({
    required String uid,
    required String token,
  }) async {
    if (token.trim().isEmpty) {
      debugPrint('[FCM] Token is empty, not saving');
      return;
    }

    try {
      await _firestore.collection('users').doc(uid).set({
        'fcmToken': token,
        'fcmTokens': FieldValue.arrayUnion([token]),
        'fcmPlatform': defaultTargetPlatform.name,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint(
        '[FCM] Token saved successfully for user $uid '
        '(${token.substring(0, 20)}...)',
      );
    } catch (e, st) {
      debugPrint('[FCM] Failed to save token: $e');
      debugPrint(st.toString());
      rethrow;
    }
  }

  void _logIncomingMessage({
    required String state,
    required RemoteMessage message,
  }) {
    final title = message.notification?.title ?? '(no title)';
    final body = message.notification?.body ?? '(no body)';
    final data = message.data.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(', ');
    debugPrint('[FCM $state] title: $title | body: $body | data: {$data}');
  }

  Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsInitialized) return;

    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const darwinSettings = DarwinInitializationSettings();
      const initializationSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      await _localNotifications.initialize(initializationSettings);

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(_androidChannel);

      _localNotificationsInitialized = true;
      debugPrint('[FCM] Local notifications initialized.');
    } catch (e, st) {
      debugPrint('[FCM] Failed to initialize local notifications: $e');
      debugPrint(st.toString());
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (!_localNotificationsInitialized) return;

    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      final muted = await isMutedForUser(uid);
      if (muted) {
        debugPrint('[FCM] Foreground notification suppressed because alerts are muted.');
        return;
      }
    }

    final title = message.notification?.title;
    final body = message.notification?.body;
    if (title == null && body == null) {
      return;
    }

    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          'Session Updates',
          channelDescription:
              'Notifications for booking, payment, and session updates',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      );

      await _localNotifications.show(
        message.hashCode,
        title,
        body,
        details,
        payload: message.data.isEmpty ? null : message.data.toString(),
      );
    } catch (e, st) {
      debugPrint('[FCM] Failed to show foreground notification: $e');
      debugPrint(st.toString());
    }
  }

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    await _authSub?.cancel();
  }

  /// Get the current FCM token for debugging purposes
  Future<String?> getToken() async {
    try {
      final token = await _messaging.getToken();
      debugPrint('[FCM] Current token: ${token?.substring(0, 20)}...');
      return token;
    } catch (e) {
      debugPrint('[FCM] Failed to get token: $e');
      return null;
    }
  }

  /// Check notification setup status
  Future<Map<String, dynamic>> getNotificationStatus() async {
    try {
      final uid = _auth.currentUser?.uid;
      final token = await _messaging.getToken();
      final settings = await _messaging.getNotificationSettings();

      final status = {
        'userId': uid,
        'isSignedIn': uid != null,
        'hasFCMToken': token != null && token.isNotEmpty,
        'authorizationStatus': settings.authorizationStatus.name,
        'initialized': _initialized,
        'supportsMessaging': _supportsMessaging,
        'localNotificationsInitialized': _localNotificationsInitialized,
      };

      debugPrint('[FCM] Notification status: $status');
      return status;
    } catch (e, st) {
      debugPrint('[FCM] Failed to get notification status: $e');
      debugPrint(st.toString());
      return {};
    }
  }
}

