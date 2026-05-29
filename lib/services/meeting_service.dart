import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MeetingService {
  MeetingService._();

  static final MeetingService instance = MeetingService._();

  String _normalizedRoomName(String sessionId) {
    final roomId = sessionId.replaceAll(RegExp(r'[^a-zA-Z0-9\-]'), '-');
    return roomId.trim().isEmpty ? 'tutoring-session' : roomId;
  }

  Uri _meetingUrl(String roomName) {
    return Uri.https('meet.ffmuc.net', '/$roomName');
  }

  Future<void> startMeeting({
    required BuildContext context,
    required String sessionId,
    String? roomName,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('You must be signed in to join this session.');
    }

    final effectiveRoomName = (roomName ?? '').trim().isNotEmpty
        ? roomName!.trim()
        : _normalizedRoomName(sessionId);
    final url = _meetingUrl(effectiveRoomName);

    var launched = await launchUrl(
      url,
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_blank',
    );
    if (!launched && !context.mounted) return;
    if (!launched) {
      launched = await launchUrl(url, mode: LaunchMode.externalApplication);
    }
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open meeting URL: $url')),
      );
    }
  }
}