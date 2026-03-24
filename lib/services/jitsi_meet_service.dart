import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';

/// Reusable service for launching Jitsi meetings inside the app.
class JitsiMeetService {
  JitsiMeetService._();

  static final JitsiMeetService instance = JitsiMeetService._();

  final JitsiMeet _jitsiMeet = JitsiMeet();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool get _supportsInAppMeeting {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  String _normalizedRoomName(String sessionId) {
    final roomId = sessionId.replaceAll(RegExp(r'[^a-zA-Z0-9\-]'), '-');
    return roomId.trim().isEmpty ? 'tutoring-session' : roomId;
  }

  Uri _meetingUrl(String roomName) {
    return Uri.https('meet.ffmuc.net', '/$roomName');
  }

  Future<_JoinIdentity> _resolveJoinIdentity({
    required String currentUid,
    required String tutorId,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final authDisplayName = (currentUser?.displayName ?? '').trim();
    final authEmail = (currentUser?.email ?? '').trim();
    final authAvatar = (currentUser?.photoURL ?? '').trim();

    final isTutor = currentUid == tutorId;

    if (isTutor) {
      try {
        final tutorDoc = await _firestore.collection('tutors').doc(tutorId).get();
        final data = tutorDoc.data() ?? <String, dynamic>{};
        final rawName = (data['name'] ?? '').toString().trim();
        final rawEmail = (data['email'] ?? '').toString().trim();
        final displayCore = rawName.isNotEmpty
            ? rawName
            : (authDisplayName.isNotEmpty ? authDisplayName : 'Tutor');

        return _JoinIdentity(
          displayName: '[Tutor] $displayCore',
          email: rawEmail.isNotEmpty ? rawEmail : (authEmail.isNotEmpty ? authEmail : null),
          avatar: authAvatar.isNotEmpty ? authAvatar : null,
        );
      } catch (e, st) {
        debugPrint('[Jitsi] Tutor identity fetch failed: $e');
        debugPrint(st.toString());
        final fallback = authDisplayName.isNotEmpty ? authDisplayName : 'Tutor';
        return _JoinIdentity(
          displayName: '[Tutor] $fallback',
          email: authEmail.isNotEmpty ? authEmail : null,
          avatar: authAvatar.isNotEmpty ? authAvatar : null,
        );
      }
    }

    try {
      final userDoc = await _firestore.collection('users').doc(currentUid).get();
      final data = userDoc.data() ?? <String, dynamic>{};
      final username = (data['username'] ?? '').toString().trim();
      final name = (data['name'] ?? '').toString().trim();
      final photoUrl = (data['photoUrl'] ?? '').toString().trim();
      final displayCore = username.isNotEmpty
          ? username
          : (name.isNotEmpty
                ? name
                : (authDisplayName.isNotEmpty ? authDisplayName : 'Student'));

      return _JoinIdentity(
        displayName: '[Student] $displayCore',
        email: authEmail.isNotEmpty ? authEmail : null,
        avatar: photoUrl.isNotEmpty
            ? photoUrl
            : (authAvatar.isNotEmpty ? authAvatar : null),
      );
    } catch (e, st) {
      debugPrint('[Jitsi] Student identity fetch failed: $e');
      debugPrint(st.toString());
      final fallback = authDisplayName.isNotEmpty ? authDisplayName : 'Student';
      return _JoinIdentity(
        displayName: '[Student] $fallback',
        email: authEmail.isNotEmpty ? authEmail : null,
        avatar: authAvatar.isNotEmpty ? authAvatar : null,
      );
    }
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
    required BuildContext context,
    required String sessionId,
    required String tutorId,
    bool audioMuted = false,
    bool videoMuted = false,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('You must be signed in to join this session.');
    }

    final roomId = _normalizedRoomName(sessionId);
    final identity = await _resolveJoinIdentity(
      currentUid: currentUser.uid,
      tutorId: tutorId,
    );

    if (!_supportsInAppMeeting) {
      await _launchInBrowser(roomId);
      return;
    }

    if (!context.mounted) return;
    final shouldJoin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Joining Session'),
        content: Text(
          'You will join as: ${identity.displayName}\nThe tutor will see this name to verify your identity.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Join Now'),
          ),
        ],
      ),
    );

    if (shouldJoin != true) return;

    final displayName = identity.displayName;
    final email = identity.email;
    final avatar = identity.avatar;

    final options = JitsiMeetConferenceOptions(
      serverURL: 'https://meet.ffmuc.net',
      room: roomId,
      configOverrides: {
        'prejoinPageEnabled': false,
        'requireDisplayName': false,
        'enableClosePage': false,
        'disableDeepLinking': true,
        'startWithAudioMuted': false,
        'startWithVideoMuted': false,
        'enableWelcomePage': false,
        'enableUserRolesBasedOnToken': false,
        'authentication': {
          'autoLogin': false,
          'enabled': false,
        },
      },
      featureFlags: {
        'prejoinpage.enabled': false,
        'unsaferoomwarning.enabled': false,
        'calendar.enabled': false,
        'invite.enabled': false,
        'android.screensharing.enabled': false,
        'welcomepage.enabled': false,
        'close-captions.enabled': false,
        'kick-out.enabled': false,
        'live-streaming.enabled': false,
        'meeting-name.enabled': false,
        'meeting-password.enabled': false,
        'notifications.enabled': false,
        'overflow-menu.enabled': false,
        'raise-hand.enabled': false,
        'recording.enabled': false,
        'server-url-change.enabled': false,
        'tile-view.enabled': true,
        'toolbox.enabled': true,
        'video-share.enabled': false,
      },
      userInfo: JitsiMeetUserInfo(
        displayName: displayName,
        email: email,
        avatar: avatar ?? '',
      ),
    );

    try {
      await _jitsiMeet.join(options);
    } catch (e, st) {
      debugPrint('[Jitsi] Failed to join room $roomId: $e');
      debugPrint(st.toString());
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not join session: $e')),
      );
    }
  }
}

class _JoinIdentity {
  final String displayName;
  final String? email;
  final String? avatar;

  const _JoinIdentity({
    required this.displayName,
    this.email,
    this.avatar,
  });
}
