import 'package:firebase_auth/firebase_auth.dart';

String resolveMeetingDisplayName(
  User? user, {
  String fallback = 'Participant',
}) {
  if (user == null) return fallback;

  final displayName = (user.displayName ?? '').trim();
  if (displayName.isNotEmpty) return displayName;

  final email = (user.email ?? '').trim();
  if (email.isNotEmpty) return email.split('@').first;

  return fallback;
}
