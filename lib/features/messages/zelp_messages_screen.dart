import 'dart:convert';


import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/tutor_model.dart';
import '../../repositories/tutors_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pressable_scale.dart';

class ZelpMessagesScreen extends StatefulWidget {
  const ZelpMessagesScreen({super.key});

  @override
  State<ZelpMessagesScreen> createState() => _ZelpMessagesScreenState();
}

class _ZelpMessagesScreenState extends State<ZelpMessagesScreen> {
  final TutorsRepository _tutorsRepository = TutorsRepository();
  final TextEditingController _messageController = TextEditingController();

  Tutor? _activeTutor;
  List<Map<String, dynamic>> _messages = [];
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _initPrefs();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _initPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _prefs = prefs;
    });
    if (_activeTutor != null) {
      _loadChatHistory(_activeTutor!.id);
    }
  }

  void _loadChatHistory(String tutorId) {
    if (_prefs == null) return;
    final jsonStr = _prefs!.getString('chat_$tutorId');
    if (jsonStr != null) {
      try {
        final decoded = json.decode(jsonStr) as List<dynamic>;
        setState(() {
          _messages = decoded.map((item) => Map<String, dynamic>.from(item)).toList();
        });
      } catch (_) {
        setState(() {
          _messages = [];
        });
      }
    } else {
      // Prepopulate mock first message if clean chat
      setState(() {
        _messages = [
          {
            'sender': 'other',
            'text': 'Hi! Feel free to ask me any questions about our upcoming sessions or topics.',
            'time': 'Just now',
          }
        ];
      });
      _saveChatHistory(tutorId);
    }
  }

  Future<void> _saveChatHistory(String tutorId) async {
    if (_prefs == null) return;
    await _prefs!.setString('chat_$tutorId', json.encode(_messages));
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty || _activeTutor == null) return;

    final newMessage = {
      'sender': 'me',
      'text': text,
      'time': DateFormat.jm(),
    };

    setState(() {
      _messages.add(newMessage);
      _messageController.clear();
    });

    _saveChatHistory(_activeTutor!.id);

    // Dynamic mock response after 1.5 seconds for visual wow factor
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted || _activeTutor == null) return;
      final autoReply = {
        'sender': 'other',
        'text': 'Sounds good! Let me review this and get back to you shortly.',
        'time': DateFormat.jm(),
      };
      setState(() {
        _messages.add(autoReply);
      });
      _saveChatHistory(_activeTutor!.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_activeTutor != null ? _activeTutor!.name : 'Inbox'),
        leading: _activeTutor != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _activeTutor = null;
                  });
                },
              )
            : null,
      ),
      body: _activeTutor == null ? _buildInboxList() : _buildChatArea(),
    );
  }

  Widget _buildInboxList() {
    return StreamBuilder<List<Tutor>>(
      stream: _tutorsRepository.getTutors(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final tutors = snapshot.data ?? [];
        if (tutors.isEmpty) {
          return const Center(
            child: Text(
              'No conversation threads yet.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: tutors.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final tutor = tutors[index];
            final names = tutor.name.split(' ');
            final initials = names.map((n) => n.isNotEmpty ? n[0] : '').take(2).join();

            // Get last message text if exists
            String lastMsg = 'Tap to message ${tutor.name}';
            if (_prefs != null) {
              final jsonStr = _prefs!.getString('chat_${tutor.id}');
              if (jsonStr != null) {
                try {
                  final decoded = json.decode(jsonStr) as List<dynamic>;
                  if (decoded.isNotEmpty) {
                    lastMsg = decoded.last['text'].toString();
                  }
                } catch (_) {}
              }
            }

            return PressableScale(
              onTap: () {
                setState(() {
                  _activeTutor = tutor;
                });
                _loadChatHistory(tutor.id);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.fromBorderSide(AppTheme.border()),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: tutor.profileImageUrl != null && tutor.profileImageUrl!.isNotEmpty
                            ? null
                            : AppTheme.buttonGradient,
                        image: tutor.profileImageUrl != null && tutor.profileImageUrl!.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(tutor.profileImageUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: tutor.profileImageUrl != null && tutor.profileImageUrl!.isNotEmpty
                          ? null
                          : Center(
                              child: Text(
                                initials.isNotEmpty ? initials : 'TR',
                                style: const TextStyle(
                                  color: AppTheme.background,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
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
                                tutor.name,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Text('Active', style: TextStyle(color: Colors.green, fontSize: 11)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            lastMsg,
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
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
    );
  }

  Widget _buildChatArea() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            reverse: true,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[_messages.length - 1 - index];
              final isMine = msg['sender'] == 'me';
              return Align(
                alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  constraints: const BoxConstraints(maxWidth: 280),
                  decoration: BoxDecoration(
                    gradient: isMine ? AppTheme.buttonGradient : null,
                    color: isMine ? null : AppTheme.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isMine ? const Radius.circular(16) : Radius.zero,
                      bottomRight: isMine ? Radius.zero : const Radius.circular(16),
                    ),
                    border: isMine ? null : Border.fromBorderSide(AppTheme.border()),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg['text'].toString(),
                        style: TextStyle(color: isMine ? AppTheme.background : AppTheme.textPrimary, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          msg['time']?.toString() ?? '',
                          style: TextStyle(
                            color: isMine ? AppTheme.background.withValues(alpha: 0.6) : AppTheme.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border(top: AppTheme.border()),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'Write a message...',
                    border: InputBorder.none,
                    isDense: true,
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
                  child: const Icon(Icons.send_rounded, color: AppTheme.background, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Minimal placeholder DateFormat to avoid dependencies issues if not imported
class DateFormat {
  static String jm() {
    final now = DateTime.now();
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final ampm = now.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }
}
