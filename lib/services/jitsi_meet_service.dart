import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';

/// Reusable service for launching Jitsi meetings inside the app.
class JitsiMeetService {
  JitsiMeetService._();

  static final JitsiMeetService instance = JitsiMeetService._();

  final JitsiMeet _jitsiMeet = JitsiMeet();

  bool get _supportsInAppMeeting {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  String _normalizedRoomName(String roomName) {
    final trimmed = roomName.trim();
    if (trimmed.isEmpty) return 'tutoring-session';

    // Keep room names URL-safe and consistent for both app and browser fallback.
    final normalized = trimmed
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '-');

    return normalized.isEmpty ? 'tutoring-session' : normalized;
  }

  Uri _meetingUrl(String roomName) {
    return Uri.https('meet.jit.si', '/$roomName');
  }

  Future<void> _launchInBrowser(String roomName) async {
    final url = _meetingUrl(roomName);
    var launched = await launchUrl(
      url,
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_blank',
    );
    if (!launched && !kIsWeb) {
      launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
    }
    if (!launched) {
      throw Exception('Could not open meeting URL: $url');
    }
  }

  Future<void> startMeeting({
    required String roomName,
    required String userName,
    bool audioMuted = false,
    bool videoMuted = false,
  }) async {
    final normalizedRoomName = _normalizedRoomName(roomName);

    if (!_supportsInAppMeeting) {
      await _launchInBrowser(normalizedRoomName);
      return;
    }

    final options = JitsiMeetConferenceOptions(
      serverURL: 'https://meet.jit.si',
      room: normalizedRoomName,
      configOverrides: {
        'startWithAudioMuted': audioMuted,
        'startWithVideoMuted': videoMuted,
        'subject': 'Tutoring Session',
      },
      featureFlags: {
        FeatureFlags.welcomePageEnabled: false,
        FeatureFlags.preJoinPageEnabled: false,
      },
      userInfo: JitsiMeetUserInfo(displayName: userName),
    );

    try {
      await _jitsiMeet.join(options);
    } catch (_) {
      // Fallback keeps Join usable when native Jitsi integration is unavailable.
      await _launchInBrowser(normalizedRoomName);
    }
  }
}
