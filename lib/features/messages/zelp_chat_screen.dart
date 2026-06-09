import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/messaging_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pressable_scale.dart';

class ZelpChatScreen extends StatefulWidget {
  final String chatId;
  final String currentUserId;
  final String otherUserId;
  final ChatParticipantMetadata currentUserMetadata;
  final ChatParticipantMetadata otherUserMetadata;

  const ZelpChatScreen({
    super.key,
    required this.chatId,
    required this.currentUserId,
    required this.otherUserId,
    required this.currentUserMetadata,
    required this.otherUserMetadata,
  });

  @override
  State<ZelpChatScreen> createState() => _ZelpChatScreenState();
}

class _ZelpChatScreenState extends State<ZelpChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  StreamSubscription<List<QueryDocumentSnapshot>>? _messagesSub;
  final List<QueryDocumentSnapshot> _loadedOlderMessages = [];
  List<QueryDocumentSnapshot> _allMessages = [];

  bool _isLoadingOlder = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _setupMessagesStream();
    _setupScrollListener();
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Sets up the stream to fetch the last 25 messages, merging them with paginated history.
  void _setupMessagesStream() {
    _messagesSub = MessagingService.instance
        .getMessagesStream(widget.chatId)
        .listen((streamDocs) {
      if (!mounted) return;
      _mergeMessages(streamDocs);
    });
  }

  /// Subscribes to scroll events to trigger older message loading when the user reaches the top.
  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (!mounted) return;
      // In a reversed ListView, maxScrollExtent corresponds to the top (oldest messages)
      final triggerPosition = _scrollController.position.maxScrollExtent - 200;
      if (_scrollController.position.pixels >= triggerPosition &&
          !_isLoadingOlder &&
          _hasMore &&
          _allMessages.isNotEmpty) {
        _loadMoreMessages();
      }
    });
  }

  /// Merges standard real-time stream messages with paginated/historical ones.
  void _mergeMessages(List<QueryDocumentSnapshot> streamDocs) {
    final Map<String, QueryDocumentSnapshot> messageMap = {};

    // 1. Put all historical messages loaded so far into the map
    for (final doc in _loadedOlderMessages) {
      messageMap[doc.id] = doc;
    }

    // 2. Overwrite or add real-time stream messages
    for (final doc in streamDocs) {
      messageMap[doc.id] = doc;
    }

    // 3. Sort by timestamp ascending
    final sorted = messageMap.values.toList()
      ..sort((a, b) {
        final tA = a.get('timestamp') as Timestamp?;
        final tB = b.get('timestamp') as Timestamp?;
        if (tA == null && tB == null) return 0;
        if (tA == null) return 1; // Server timestamp is still null locally, place it at the end
        if (tB == null) return -1;
        return tA.compareTo(tB);
      });

    setState(() {
      _allMessages = sorted;
    });
  }

  /// Fetches another batch of 25 older messages.
  Future<void> _loadMoreMessages() async {
    if (_isLoadingOlder || !_hasMore || _allMessages.isEmpty) return;

    setState(() {
      _isLoadingOlder = true;
    });

    try {
      // The first element in our ascending sorted list is the oldest one we have loaded.
      final oldestDoc = _allMessages.first;

      final snapshot = await MessagingService.instance.loadOlderMessages(
        chatId: widget.chatId,
        startBeforeDoc: oldestDoc,
        limit: 25,
      );

      final newDocs = snapshot.docs;

      if (newDocs.length < 25) {
        _hasMore = false;
      }

      if (newDocs.isNotEmpty) {
        _loadedOlderMessages.addAll(newDocs);
        // Force merge and update the UI
        _mergeMessages([]);
      }
    } catch (e) {
      debugPrint('[ZelpChatScreen] Error loading older messages: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingOlder = false;
        });
      }
    }
  }

  /// Sends a text message, clears inputs and triggers updates.
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    try {
      await MessagingService.instance.sendMessage(
        chatId: widget.chatId,
        senderId: widget.currentUserId,
        text: text,
        participants: [widget.currentUserId, widget.otherUserId],
        metadata: {
          widget.currentUserId: widget.currentUserMetadata,
          widget.otherUserId: widget.otherUserMetadata,
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final otherName = widget.otherUserMetadata.displayName;
    final otherPhoto = widget.otherUserMetadata.photoURL;

    final names = otherName.split(' ');
    final initials = names.map((n) => n.isNotEmpty ? n[0] : '').take(2).join();

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: otherPhoto.isNotEmpty ? null : AppTheme.buttonGradient,
                image: otherPhoto.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(otherPhoto),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: otherPhoto.isEmpty
                  ? Center(
                      child: Text(
                        initials.isNotEmpty ? initials : 'TR',
                        style: const TextStyle(
                          color: AppTheme.background,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    otherName,
                    style: TextStyle(
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Active',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Message History list
          Expanded(
            child: _allMessages.isEmpty
                ? Center(
                    child: Text(
                      'No messages yet. Say hello!',
                      style: TextStyle(
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true, // Newer messages at the bottom
                    padding: const EdgeInsets.all(16),
                    itemCount: _allMessages.length + (_isLoadingOlder ? 1 : 0),
                    itemBuilder: (context, index) {
                      // If we are showing loading indicator at the end (top of reversed list)
                      if (index == _allMessages.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }

                      // ListView is reversed: index 0 is at the bottom (newest)
                      // So index `index` in reversed corresponds to index `_allMessages.length - 1 - index` in ascending ordered messages
                      final doc = _allMessages[_allMessages.length - 1 - index];
                      final senderId = doc.get('senderId')?.toString() ?? '';
                      final text = doc.get('text')?.toString() ?? '';
                      final timestamp = doc.get('timestamp') as Timestamp?;

                      final isMine = senderId == widget.currentUserId;

                      return _buildMessageBubble(
                        text: text,
                        isMine: isMine,
                        timestamp: timestamp,
                        isDark: isDark,
                      );
                    },
                  ),
          ),

          // Message Input Field
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
              border: Border(
                top: BorderSide(
                  color: AppTheme.primary.withValues(alpha: isDark ? 0.22 : 0.14),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: TextStyle(
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Write a message...',
                      hintStyle: TextStyle(
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 10),
                PressableScale(
                  onTap: _sendMessage,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: AppTheme.buttonGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: AppTheme.glow(),
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: AppTheme.background,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({
    required String text,
    required bool isMine,
    required Timestamp? timestamp,
    required bool isDark,
  }) {
    final timeStr = timestamp != null ? _formatTimestamp(timestamp) : 'Sending...';

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          gradient: isMine ? AppTheme.buttonGradient : null,
          color: isMine ? null : (isDark ? AppTheme.darkSurface : AppTheme.lightSurface),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMine ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMine ? Radius.zero : const Radius.circular(16),
          ),
          border: isMine
              ? null
              : Border.all(
                  color: AppTheme.primary.withValues(alpha: isDark ? 0.22 : 0.14),
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(
                color: isMine ? AppTheme.background : (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                timeStr,
                style: TextStyle(
                  color: isMine
                      ? AppTheme.background.withValues(alpha: 0.6)
                      : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final ampm = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }
}
