import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

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
  StreamSubscription<ChatRoom?>? _chatRoomSub;
  
  final List<QueryDocumentSnapshot> _loadedOlderMessages = [];
  List<QueryDocumentSnapshot> _allMessages = [];

  bool _isLoadingOlder = false;
  bool _hasMore = true;
  
  Timer? _typingTimer;
  bool _isTyping = false;
  bool _otherIsTyping = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _setupMessagesStream();
    _setupChatRoomStream();
    _setupScrollListener();
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    _chatRoomSub?.cancel();
    _typingTimer?.cancel();
    _messageController.removeListener(_onTextChanged);
    if (_isTyping) {
      MessagingService.instance.updateTypingStatus(widget.chatId, widget.currentUserId, false);
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupChatRoomStream() {
    _chatRoomSub = MessagingService.instance.getChatRoomStream(widget.chatId).listen((room) {
      if (!mounted || room == null) return;
      final typingMap = room.typing;
      setState(() {
        _otherIsTyping = typingMap[widget.otherUserId] == true;
      });
    });
  }

  void _onTextChanged() {
    if (_messageController.text.isNotEmpty) {
      if (!_isTyping) {
        _isTyping = true;
        MessagingService.instance.updateTypingStatus(widget.chatId, widget.currentUserId, true);
      }
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        _isTyping = false;
        MessagingService.instance.updateTypingStatus(widget.chatId, widget.currentUserId, false);
      });
    }
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
      
      // Check if message is from the other user and not viewed yet
      final data = doc.data() as Map<String, dynamic>;
      final senderId = data['senderId']?.toString() ?? '';
      final isViewed = data['isViewed'] == true;
      
      if (senderId == widget.otherUserId && !isViewed) {
        MessagingService.instance.markMessageAsViewed(widget.chatId, doc.id);
      }
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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      _uploadAndSendMessage(File(pickedFile.path), isImage: true);
    }
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
    );
    if (result != null && result.files.single.path != null) {
      _uploadAndSendMessage(File(result.files.single.path!), isImage: false, docName: result.files.single.name);
    }
  }

  Future<void> _uploadAndSendMessage(File file, {required bool isImage, String? docName}) async {
    setState(() => _isUploading = true);
    try {
      final ext = isImage ? 'jpg' : (docName?.split('.').last ?? 'pdf');
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final ref = FirebaseStorage.instance.ref().child('chats/${widget.chatId}/$fileName');
      final uploadTask = await ref.putFile(file);
      final url = await uploadTask.ref.getDownloadURL();

      await MessagingService.instance.sendMessage(
        chatId: widget.chatId,
        senderId: widget.currentUserId,
        text: '',
        participants: [widget.currentUserId, widget.otherUserId],
        metadata: {
          widget.currentUserId: widget.currentUserMetadata,
          widget.otherUserId: widget.otherUserMetadata,
        },
        imageUrl: isImage ? url : null,
        documentUrl: !isImage ? url : null,
        documentName: !isImage ? docName : null,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  /// Sends a text message, clears inputs and triggers updates.
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    
    // Stop typing immediately when sent
    if (_isTyping) {
      _isTyping = false;
      _typingTimer?.cancel();
      MessagingService.instance.updateTypingStatus(widget.chatId, widget.currentUserId, false);
    }

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

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open file.')),
        );
      }
    }
  }

  void _showMessageOptions(BuildContext context, String messageId, bool isMine, String? fileUrl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkSurface : AppTheme.lightSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (fileUrl != null)
              ListTile(
                leading: const Icon(Icons.download, color: AppTheme.primary),
                title: const Text('Save / Open File'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _openUrl(fileUrl);
                },
              ),
            if (isMine)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete Message', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  try {
                    await MessagingService.instance.deleteMessage(widget.chatId, messageId);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to delete: $e')),
                      );
                    }
                  }
                },
              ),
          ],
        ),
      ),
    );
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
                    _otherIsTyping ? 'Typing...' : 'Active',
                    style: TextStyle(
                      color: _otherIsTyping ? AppTheme.primary : Colors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                      final docIndex = _allMessages.length - 1 - index;
                      final doc = _allMessages[docIndex];
                      final timestamp = doc.get('timestamp') as Timestamp?;
                      
                      bool showDaySeparator = false;
                      if (index == _allMessages.length - 1) {
                         showDaySeparator = true; 
                      } else {
                         final previousDoc = _allMessages[docIndex - 1];
                         final previousTimestamp = previousDoc.get('timestamp') as Timestamp?;
                         if (timestamp != null && previousTimestamp != null) {
                            final d1 = timestamp.toDate();
                            final d2 = previousTimestamp.toDate();
                            if (d1.year != d2.year || d1.month != d2.month || d1.day != d2.day) {
                               showDaySeparator = true;
                            }
                         }
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showDaySeparator && timestamp != null)
                            _buildDaySeparator(timestamp, isDark),
                          _buildMessageBubble(doc: doc, isDark: isDark),
                        ],
                      );
                    },
                  ),
          ),

          if (_isUploading)
            LinearProgressIndicator(
              backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
              color: AppTheme.primary,
            ),

          // Message Input Field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
                IconButton(
                  icon: Icon(Icons.image_outlined, color: AppTheme.primary),
                  onPressed: _pickImage,
                  tooltip: 'Send Image',
                ),
                IconButton(
                  icon: Icon(Icons.attach_file, color: AppTheme.primary),
                  onPressed: _pickDocument,
                  tooltip: 'Send Document',
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
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
                      borderRadius: BorderRadius.circular(22),
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
  
  Widget _buildDaySeparator(Timestamp timestamp, bool isDark) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    String dayString;
    
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      dayString = 'Today';
    } else if (date.year == now.year && date.month == now.month && date.day == now.day - 1) {
      dayString = 'Yesterday';
    } else {
      dayString = DateFormat('MMM d, yyyy').format(date);
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            dayString,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble({
    required QueryDocumentSnapshot doc,
    required bool isDark,
  }) {
    final data = doc.data() as Map<String, dynamic>;
    final senderId = data['senderId']?.toString() ?? '';
    final text = data['text']?.toString() ?? '';
    final timestamp = doc.get('timestamp') as Timestamp?;
    
    final isViewed = data['isViewed'] == true;
    final imageUrl = data['imageUrl']?.toString();
    final documentUrl = data['documentUrl']?.toString();
    final documentName = data['documentName']?.toString();
    
    final isMine = senderId == widget.currentUserId;
    final timeStr = timestamp != null ? _formatTimestamp(timestamp) : 'Sending...';

    Widget content;
    final textWidget = text.isEmpty ? const SizedBox() : Text(
      text,
      style: TextStyle(
        color: isMine ? AppTheme.background : (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
        fontSize: 14,
      ),
    );

    if (imageUrl != null) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _openUrl(imageUrl),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(imageUrl, width: 220, fit: BoxFit.cover),
            ),
          ),
          if (text.isNotEmpty) const SizedBox(height: 6),
          textWidget,
        ],
      );
    } else if (documentUrl != null) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _openUrl(documentUrl),
            child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isMine ? Colors.white24 : (isDark ? Colors.black12 : Colors.black.withValues(alpha: 0.05)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.insert_drive_file, color: isMine ? Colors.white : AppTheme.primary, size: 28),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    documentName ?? 'Document',
                    style: TextStyle(
                      color: isMine ? Colors.white : AppTheme.primary,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          ),
          if (text.isNotEmpty) const SizedBox(height: 6),
          textWidget,
        ],
      );
    } else {
      content = textWidget;
    }

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(context, doc.id, isMine, imageUrl ?? documentUrl),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
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
            content,
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    color: isMine
                        ? AppTheme.background.withValues(alpha: 0.7)
                        : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                    fontSize: 10,
                  ),
                ),
                if (isMine) const SizedBox(width: 4),
                if (isMine)
                  Icon(
                    isViewed ? Icons.done_all : Icons.check,
                    size: 14,
                    color: isViewed ? Colors.blue[200] : AppTheme.background.withValues(alpha: 0.7),
                  ),
              ],
            ),
          ],
        ),
      ),
    ));
  }

  String _formatTimestamp(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    return DateFormat.jm().format(dateTime); // E.g., 2:30 PM
  }
}
