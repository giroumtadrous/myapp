import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/messaging_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_transitions.dart';
import '../../widgets/pressable_scale.dart';
import 'zelp_chat_screen.dart';

class ZelpMessagesScreen extends StatefulWidget {
  const ZelpMessagesScreen({super.key});

  @override
  State<ZelpMessagesScreen> createState() => _ZelpMessagesScreenState();
}

class _ZelpMessagesScreenState extends State<ZelpMessagesScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _resolvedUid;
  bool _loadingId = true;

  @override
  void initState() {
    super.initState();
    _resolveUid();
  }

  Future<void> _resolveUid() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _loadingId = false);
        return;
      }
      
      // Query if this user is a tutor to get their business ID (e.g., tutor_001)
      final tutorQuery = await FirebaseFirestore.instance
          .collection('tutors')
          .where('authUid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (tutorQuery.docs.isNotEmpty) {
        _resolvedUid = tutorQuery.docs.first.id;
      } else {
        _resolvedUid = user.uid;
      }
    } catch (e) {
      debugPrint('[ZelpMessagesScreen] Error resolving UID: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingId = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loadingId) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
        appBar: AppBar(
          backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
          title: const Text('Inbox'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_resolvedUid == null) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
        appBar: AppBar(
          backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
          title: const Text('Inbox'),
        ),
        body: const Center(
          child: Text(
            'Please log in to view your messages.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
        title: const Text('Inbox'),
      ),
      body: StreamBuilder<List<ChatRoom>>(
        stream: MessagingService.instance.getChatRoomsStream(_resolvedUid!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load messages: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final chatRooms = snapshot.data ?? [];

          if (chatRooms.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 64,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No conversation threads yet.',
                    style: TextStyle(
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: chatRooms.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final chatRoom = chatRooms[index];
              
              // Identify the other participant's UID
              final otherUserId = chatRoom.participants.firstWhere(
                (id) => id != _resolvedUid,
                orElse: () => '',
              );

              if (otherUserId.isEmpty) return const SizedBox.shrink();

              // Get other participant and current participant metadata from the map
              final otherUserMeta = chatRoom.metadata[otherUserId] ??
                  ChatParticipantMetadata(displayName: 'User', photoURL: '');
              
              final currentUserMeta = chatRoom.metadata[_resolvedUid] ??
                  ChatParticipantMetadata(
                    displayName: _auth.currentUser?.displayName ?? 'Me',
                    photoURL: _auth.currentUser?.photoURL ?? '',
                  );

              final names = otherUserMeta.displayName.split(' ');
              final initials = names.map((n) => n.isNotEmpty ? n[0] : '').take(2).join();

              return PressableScale(
                onTap: () {
                  Navigator.of(context).push(
                    AppTransitions.slideFromRight(
                      page: ZelpChatScreen(
                        chatId: chatRoom.id,
                        currentUserId: _resolvedUid!,
                        otherUserId: otherUserId,
                        currentUserMetadata: currentUserMeta,
                        otherUserMetadata: otherUserMeta,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.fromBorderSide(
                      BorderSide(
                        color: AppTheme.primary.withValues(alpha: isDark ? 0.22 : 0.14),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: otherUserMeta.photoURL.isNotEmpty ? null : AppTheme.buttonGradient,
                          image: otherUserMeta.photoURL.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(otherUserMeta.photoURL),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: otherUserMeta.photoURL.isEmpty
                            ? Center(
                                child: Text(
                                  initials.isNotEmpty ? initials : 'TR',
                                  style: const TextStyle(
                                    color: AppTheme.background,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  otherUserMeta.displayName,
                                  style: TextStyle(
                                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  _formatTimestamp(chatRoom.updatedAt),
                                  style: TextStyle(
                                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              chatRoom.lastMessage.isNotEmpty ? chatRoom.lastMessage : 'Tap to message',
                              style: TextStyle(
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inDays >= 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays >= 1) {
      return '${difference.inDays}d ago';
    } else {
      final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
      final minute = date.minute.toString().padLeft(2, '0');
      final ampm = date.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $ampm';
    }
  }
}
