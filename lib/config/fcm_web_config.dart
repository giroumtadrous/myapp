/// Web push VAPID key from Firebase Console:
/// Project settings → Cloud Messaging → Web Push certificates → Key pair.
///
/// Paste the public key here so FCM can register tokens on web (Chrome).
/// Leave null to skip web push token registration.
class FcmWebConfig {
  static const String vapidKey = 'BP5KV3QoRZIZGea_M-ejbHa8QlOJ6OWZc7En1gwrdumMzaf_wnYjW5RsvWf539SwXAdU4I8-cX22hvAbxxamLpA';
}
