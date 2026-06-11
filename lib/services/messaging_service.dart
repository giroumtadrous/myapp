import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

// ── Models ──────────────────────────────────────────────────────────

// ... [existing ChatRoom, ChatParticipantMetadata, and MessageModel classes]

class ChatRoom {
  final String id; // studentUid_tutorUid
  final List<String> participants;
  final String lastMessage;
  final Timestamp updatedAt;
  final Map<String, ChatParticipantMetadata> metadata;
  final Map<String, bool> typing;

  ChatRoom({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.updatedAt,
    required this.metadata,
    required this.typing,
  });

  factory ChatRoom.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawMetadata = data['metadata'] as Map<String, dynamic>? ?? {};
    final metadataMap = rawMetadata.map((key, value) {
      final valMap = Map<String, dynamic>.from(value as Map? ?? {});
      return MapEntry(
        key,
        ChatParticipantMetadata(
          displayName: valMap['displayName']?.toString() ?? '',
          photoURL: valMap['photoURL']?.toString() ?? '',
        ),
      );
    });

    final rawTyping = data['typing'] as Map<String, dynamic>? ?? {};
    final typingMap = rawTyping.map((key, value) => MapEntry(key, value == true));

    return ChatRoom(
      id: doc.id,
      participants: List<String>.from(data['participants'] as List? ?? []),
      lastMessage: data['lastMessage']?.toString() ?? '',
      updatedAt: data['updatedAt'] as Timestamp? ?? Timestamp.now(),
      metadata: metadataMap,
      typing: typingMap,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'participants': participants,
      'lastMessage': lastMessage,
      'updatedAt': updatedAt,
      'metadata': metadata.map((key, value) => MapEntry(key, value.toMap())),
      'typing': typing,
    };
  }
}

class ChatParticipantMetadata {
  final String displayName;
  final String photoURL;

  ChatParticipantMetadata({
    required this.displayName,
    required this.photoURL,
  });

  factory ChatParticipantMetadata.fromMap(Map<String, dynamic> map) {
    return ChatParticipantMetadata(
      displayName: map['displayName']?.toString() ?? map['name']?.toString() ?? '',
      photoURL: map['photoURL']?.toString() ?? map['photoUrl']?.toString() ?? map['profileImageUrl']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'photoURL': photoURL,
    };
  }
}

class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final Timestamp timestamp;
  final bool isViewed;
  final String? imageUrl;
  final String? documentUrl;
  final String? documentName;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.isViewed = false,
    this.imageUrl,
    this.documentUrl,
    this.documentName,
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return MessageModel(
      id: doc.id,
      senderId: data['senderId']?.toString() ?? '',
      text: data['text']?.toString() ?? '',
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
      isViewed: data['isViewed'] == true,
      imageUrl: data['imageUrl']?.toString(),
      documentUrl: data['documentUrl']?.toString(),
      documentName: data['documentName']?.toString(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'text': text,
      'timestamp': timestamp,
      'isViewed': isViewed,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (documentUrl != null) 'documentUrl': documentUrl,
      if (documentName != null) 'documentName': documentName,
    };
  }
}

// ── Service & Repository Layer ──────────────────────────────────────

class MessagingService {
  MessagingService._();
  static final MessagingService instance = MessagingService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Initializes Firestore settings, enabling persistent offline caching.
  void setupOfflineCaching() {
    try {
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      debugPrint('[MessagingService] Firestore persistent cache enabled.');
    } catch (e) {
      debugPrint('[MessagingService] Error setting offline cache (likely already initialized): $e');
    }
  }

  /// Generates a consistent chat ID between two users by sorting UIDs alphabetically.
  String getChatId(String uidA, String uidB) {
    final ids = [uidA, uidB];
    ids.sort();
    return ids.join('_');
  }

  /// Emits a stream of real-time chats for a user, sorted by most recently updated.
  Stream<List<ChatRoom>> getChatRoomsStream(String currentUserId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ChatRoom.fromFirestore(doc)).toList());
  }

  /// Stream a single chat room to listen for typing status.
  Stream<ChatRoom?> getChatRoomStream(String chatId) {
    return _firestore.collection('chats').doc(chatId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ChatRoom.fromFirestore(doc);
    });
  }

  /// Update typing status for a user in a chat
  Future<void> updateTypingStatus(String chatId, String userId, bool isTyping) async {
    await _firestore.collection('chats').doc(chatId).set({
      'typing': {userId: isTyping}
    }, SetOptions(merge: true));
  }

  /// Mark a message as viewed
  Future<void> markMessageAsViewed(String chatId, String messageId) async {
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({'isViewed': true});
  }

  /// Stream to fetch the last 25 messages of a chat room.
  Stream<List<QueryDocumentSnapshot>> getMessagesStream(String chatId, {int limit = 25}) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp')
        .limitToLast(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  /// Paginate and load the next 25 older messages.
  Future<QuerySnapshot> loadOlderMessages({
    required String chatId,
    required DocumentSnapshot startBeforeDoc,
    int limit = 25,
  }) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp')
        .endBeforeDocument(startBeforeDoc)
        .limitToLast(limit)
        .get();
  }

  /// Sends a message and updates the parent chat room info inside an atomic batch operation.
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
    required List<String> participants,
    required Map<String, ChatParticipantMetadata> metadata,
    String? imageUrl,
    String? documentUrl,
    String? documentName,
  }) async {
    final batch = _firestore.batch();
    final chatDocRef = _firestore.collection('chats').doc(chatId);
    final msgDocRef = chatDocRef.collection('messages').doc();

    final timestamp = FieldValue.serverTimestamp();

    // 1. Add message document
    batch.set(msgDocRef, {
      'senderId': senderId,
      'text': text,
      'timestamp': timestamp,
      'isViewed': false,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (documentUrl != null) 'documentUrl': documentUrl,
      if (documentName != null) 'documentName': documentName,
    });

    // 2. Update chat metadata and last message stats
    String displayLastMessage = text;
    if (text.isEmpty) {
      if (imageUrl != null) displayLastMessage = '📷 Image';
      if (documentUrl != null) displayLastMessage = '📄 Document';
    }

    batch.set(chatDocRef, {
      'participants': participants,
      'lastMessage': displayLastMessage,
      'updatedAt': timestamp,
      'metadata': metadata.map((key, value) => MapEntry(key, value.toMap())),
    }, SetOptions(merge: true));

    await batch.commit();
  }
}
