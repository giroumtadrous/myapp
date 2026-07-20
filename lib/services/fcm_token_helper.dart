import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config/fcm_web_config.dart';

Future<String?> fetchFcmDeviceToken(FirebaseMessaging messaging) async {
  if (kIsWeb) {
    final vapidKey = FcmWebConfig.vapidKey.trim();
    if (vapidKey.isEmpty) {
      debugPrint(
        '[FCM] Web push needs a VAPID key. Add it in lib/config/fcm_web_config.dart '
        '(Firebase Console → Cloud Messaging → Web Push certificates).',
      );
      return null;
    }
    return messaging.getToken(vapidKey: vapidKey);
  }

  return messaging.getToken();
}
