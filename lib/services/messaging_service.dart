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

  ChatRoom({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.updatedAt,
    required this.metadata,
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

    return ChatRoom(
      id: doc.id,
      participants: List<String>.from(data['participants'] as List? ?? []),
      lastMessage: data['lastMessage']?.toString() ?? '',
      updatedAt: data['updatedAt'] as Timestamp? ?? Timestamp.now(),
      metadata: metadataMap,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'participants': participants,
      'lastMessage': lastMessage,
      'updatedAt': updatedAt,
      'metadata': metadata.map((key, value) => MapEntry(key, value.toMap())),
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

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return MessageModel(
      id: doc.id,
      senderId: data['senderId']?.toString() ?? '',
      text: data['text']?.toString() ?? '',
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'text': text,
      'timestamp': timestamp,
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
    });

    // 2. Update chat metadata and last message stats
    batch.set(chatDocRef, {
      'participants': participants,
      'lastMessage': text,
      'updatedAt': timestamp,
      'metadata': metadata.map((key, value) => MapEntry(key, value.toMap())),
    }, SetOptions(merge: true));

    await batch.commit();
  }
}
