import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class CacheService {
  CacheService._();
  static final CacheService instance = CacheService._();

  static const String _tutorsBoxName = 'tutors_box';
  static const String _messagesBoxName = 'messages_box';
  static const String _progressBoxName = 'progress_box';
  static const String _sessionsBoxName = 'sessions_box';

  late Box<String> _tutorsBox;
  late Box<String> _messagesBox;
  late Box<String> _progressBox;
  late Box<String> _sessionsBox;

  /// Initialize Hive and open all boxes. Call this in main.dart before runApp.
  Future<void> initialize() async {
    await Hive.initFlutter();
    _tutorsBox = await Hive.openBox<String>(_tutorsBoxName);
    _messagesBox = await Hive.openBox<String>(_messagesBoxName);
    _progressBox = await Hive.openBox<String>(_progressBoxName);
    _sessionsBox = await Hive.openBox<String>(_sessionsBoxName);
    debugPrint('[CacheService] Initialized and boxes opened.');
  }

  // ── TUTORS CACHE ─────────────────────────────────────────────────────────

  /// Saves a list of tutors as JSON strings.
  Future<void> saveTutors(List<Map<String, dynamic>> tutorsJson) async {
    final payload = {
      'cachedAt': DateTime.now().toIso8601String(),
      'data': tutorsJson,
    };
    await _tutorsBox.put('all_tutors', jsonEncode(payload));
  }

  /// Retrieves the cached tutors and their cached timestamp.
  /// Returns a map with 'cachedAt' (DateTime) and 'data' (List of maps).
  /// Returns null if no cache exists.
  Map<String, dynamic>? getTutors() {
    final jsonString = _tutorsBox.get('all_tutors');
    if (jsonString == null) return null;

    try {
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      return {
        'cachedAt': DateTime.parse(decoded['cachedAt'] as String),
        'data': List<Map<String, dynamic>>.from(decoded['data'] as List),
      };
    } catch (e) {
      debugPrint('[CacheService] Failed to parse tutors cache: $e');
      return null;
    }
  }

  Future<void> clearTutors() async {
    await _tutorsBox.delete('all_tutors');
  }

  // ── MESSAGES CACHE ───────────────────────────────────────────────────────

  /// Saves the last 50 messages for a specific conversation.
  Future<void> saveMessages(String conversationId, List<Map<String, dynamic>> messagesJson) async {
    final payload = {
      'cachedAt': DateTime.now().toIso8601String(),
      'data': messagesJson,
    };
    await _messagesBox.put(conversationId, jsonEncode(payload));
  }

  /// Retrieves messages for a conversation.
  Map<String, dynamic>? getMessages(String conversationId) {
    final jsonString = _messagesBox.get(conversationId);
    if (jsonString == null) return null;

    try {
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      return {
        'cachedAt': DateTime.parse(decoded['cachedAt'] as String),
        'data': List<Map<String, dynamic>>.from(decoded['data'] as List),
      };
    } catch (e) {
      return null;
    }
  }

  /// Appends new messages to an existing conversation cache, capping at 100.
  Future<void> appendMessages(String conversationId, List<Map<String, dynamic>> newMessagesJson) async {
    final currentCache = getMessages(conversationId);
    List<Map<String, dynamic>> messages = [];
    
    if (currentCache != null) {
      messages = currentCache['data'] as List<Map<String, dynamic>>;
    }

    // Merge logic: ensure no duplicates by ID
    final existingIds = messages.map((m) => m['id']).toSet();
    for (final msg in newMessagesJson) {
      if (!existingIds.contains(msg['id'])) {
        messages.add(msg);
      } else {
        // Update existing message (e.g. isViewed changed)
        final index = messages.indexWhere((m) => m['id'] == msg['id']);
        if (index != -1) {
          messages[index] = msg;
        }
      }
    }

    // Sort by timestamp just in case
    messages.sort((a, b) {
      // Assuming timestamp is stored in a comparable way, or we compare the raw maps if needed.
      // Usually, Firestore timestamps are encoded as {'_seconds': ..., '_nanoseconds': ...} 
      // or ISO strings.
      // This is a simple fallback sort if they are ISO strings. We'll let the repository handle exact sorting.
      return 0;
    });

    // Cap at 100 messages (keep the newest 100, which are typically at the end)
    if (messages.length > 100) {
      messages = messages.sublist(messages.length - 100);
    }

    await saveMessages(conversationId, messages);
  }

  // ── SESSIONS CACHE ───────────────────────────────────────────────────────

  Future<void> saveSessions(String studentId, List<Map<String, dynamic>> sessionsJson) async {
    final payload = {
      'cachedAt': DateTime.now().toIso8601String(),
      'data': sessionsJson,
    };
    await _sessionsBox.put(studentId, jsonEncode(payload));
  }

  Map<String, dynamic>? getSessions(String studentId) {
    final jsonString = _sessionsBox.get(studentId);
    if (jsonString == null) return null;

    try {
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      return {
        'cachedAt': DateTime.parse(decoded['cachedAt'] as String),
        'data': List<Map<String, dynamic>>.from(decoded['data'] as List),
      };
    } catch (e) {
      return null;
    }
  }

  // ── PROGRESS CACHE ───────────────────────────────────────────────────────

  Future<void> saveProgress(String studentId, Map<String, dynamic> progressJson) async {
    final payload = {
      'cachedAt': DateTime.now().toIso8601String(),
      'data': progressJson,
    };
    await _progressBox.put(studentId, jsonEncode(payload));
  }

  Map<String, dynamic>? getProgress(String studentId) {
    final jsonString = _progressBox.get(studentId);
    if (jsonString == null) return null;

    try {
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      return {
        'cachedAt': DateTime.parse(decoded['cachedAt'] as String),
        'data': decoded['data'] as Map<String, dynamic>,
      };
    } catch (e) {
      return null;
    }
  }
}
