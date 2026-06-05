import 'package:flutter/material.dart';

import '../services/notification_service.dart';

/// Ensures FCM is initialized and the device token is saved after login.
class NotificationAuthSync extends StatefulWidget {
  const NotificationAuthSync({super.key, required this.child});

  final Widget child;

  @override
  State<NotificationAuthSync> createState() => _NotificationAuthSyncState();
}

class _NotificationAuthSyncState extends State<NotificationAuthSync> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NotificationService.instance.initialize();
      await NotificationService.instance.syncTokenForCurrentUser();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
