import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/review_model.dart';
import '../../models/tutor_model.dart';
import '../../repositories/reviews_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_transitions.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/pressable_scale.dart';
import '../../widgets/zelp_ui_components.dart';
import 'manual_payment_screen.dart';
import '../../services/messaging_service.dart';
import '../messages/zelp_chat_screen.dart';

class ZelpTutorProfileScreen extends StatefulWidget {
  final Tutor tutor;

  const ZelpTutorProfileScreen({super.key, required this.tutor});

  @override
  State<ZelpTutorProfileScreen> createState() => _ZelpTutorProfileScreenState();
}

class _ZelpTutorProfileScreenState extends State<ZelpTutorProfileScreen> {
  static const List<String> _blockingStatuses = <String>[
    'pending',
    'confirmed',
    'booked',
    'pending_payment_verification',
    'approved',
  ];

  final ReviewsRepository _reviewsRepository = ReviewsRepository();

  int _selectedSubjectIndex = 0;
  int _selectedDurationMinutes = 60;
  int _selectedDateIndex = 0;
  int? _selectedSlotIndex;

  late final List<DateTime> _dates;
  List<String> _availableSlots = [];
  List<String> _allSlotValuesForSelectedDay = [];
  bool _loadingSlots = false;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _tutorDocSubscription;

  @override
  void initState() {
    super.initState();
    // Generate dates for the next 14 days
    _dates = List.generate(
      14,
      (index) {
        final d = DateTime.now().add(Duration(days: index));
        return DateTime(d.year, d.month, d.day);
      },
    );
    _subscribeToTutorAvailability();
    _loadSlotsForDate(_dates[_selectedDateIndex]);
  }

  @override
  void dispose() {
    _tutorDocSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToTutorAvailability() {
    _tutorDocSubscription = FirebaseFirestore.instance
        .collection('tutors')
        .doc(widget.tutor.id)
        .snapshots()
        .listen((snapshot) {
      if (!mounted || !snapshot.exists) return;
      _loadSlotsForDate(_dates[_selectedDateIndex]);
    });
  }

  Map<String, List<String>> _extractWeeklyAvailability(
    Map<String, dynamic> data,
  ) {
    final raw = data['weeklyAvailability'] ?? data['weekly_availability'];
    if (raw is! Map) return <String, List<String>>{};

    final result = <String, List<String>>{};
    raw.forEach((key, value) {
      if (value is List) {
        result[key.toString().toLowerCase()] = List<String>.from(
          value.map((e) => e.toString()),
        );
      }
    });
    return result;
  }

  List<String> _generateSlotsForDay(
    DateTime date,
    Map<String, List<String>> weekly,
  ) {
    final weekdayName = DateFormat.EEEE().format(date).toLowerCase();
    final avail = weekly[weekdayName] ?? [];
    if (avail.isEmpty) return [];

    final slots = <DateTime>[];
    for (final t in avail) {
      try {
        DateTime dt = DateFormat('HH:mm').parseLoose(t.toString());
        dt = DateTime(date.year, date.month, date.day, dt.hour, dt.minute);
        slots.add(dt);
      } catch (_) {}
    }

    slots.sort((a, b) => a.compareTo(b));
    return slots
        .map(
          (dt) => '${DateFormat('HH:mm').format(dt)}|${DateFormat.jm().format(dt)}',
        )
        .toList();
  }

  int _requiredSlotCount() {
    return _selectedDurationMinutes == 120 ? 2 : 1;
  }

  Set<String> _occupiedSlotsForDate(
    List<String> daySlots,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> bookedDocs,
  ) {
    final occupied = <String>{};
    final slotValues = daySlots.map((slot) => slot.split('|')[0]).toList();

    for (final doc in bookedDocs) {
      final data = doc.data();
      final reservedRaw = data['reservedSlots'];
      if (reservedRaw is List && reservedRaw.isNotEmpty) {
        for (final slot in reservedRaw) {
          final value = slot.toString().trim();
          if (value.isNotEmpty) occupied.add(value);
        }
        continue;
      }

      final startTimeRaw = data['time']?.toString() ?? '';
      if (startTimeRaw.isEmpty) continue;

      String startValue;
      try {
        startValue = DateFormat('HH:mm').format(
          DateFormat('HH:mm').parseLoose(startTimeRaw),
        );
      } catch (_) {
        try {
          startValue = DateFormat('HH:mm').format(
            DateFormat.jm().parseLoose(startTimeRaw),
          );
        } catch (_) {
          startValue = startTimeRaw;
        }
      }

      final startIndex = slotValues.indexOf(startValue);
      if (startIndex == -1) {
        occupied.add(startValue);
        continue;
      }

      final durationRaw = data['durationMinutes'];
      final slotCountRaw = data['slotCount'];
      int slotCount = 1;
      if (slotCountRaw is num) {
        slotCount = slotCountRaw.toInt().clamp(1, 24);
      } else if (durationRaw is num) {
        slotCount = (durationRaw.toInt() / 60).round().clamp(1, 24);
      }

      for (int i = 0; i < slotCount; i++) {
        final idx = startIndex + i;
        if (idx >= slotValues.length) break;
        occupied.add(slotValues[idx]);
      }
    }

    return occupied;
  }

  List<String> _availableStartSlots(
    List<String> daySlots,
    Set<String> occupied,
    int requiredSlots,
  ) {
    if (daySlots.isEmpty) return const [];

    final slotValues = daySlots.map((slot) => slot.split('|')[0]).toList();
    final available = <String>[];

    for (int i = 0; i < daySlots.length; i++) {
      if (i + requiredSlots > daySlots.length) break;

      bool allFree = true;
      for (int offset = 0; offset < requiredSlots; offset++) {
        final slotToCheck = slotValues[i + offset];
        if (occupied.contains(slotToCheck)) {
          allFree = false;
          break;
        }
      }

      if (allFree) {
        available.add(daySlots[i]);
      }
    }

    return available;
  }

  Future<void> _loadSlotsForDate(DateTime date) async {
    if (!mounted) return;
    setState(() => _loadingSlots = true);

    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    try {
      final tutorDoc = await FirebaseFirestore.instance
          .collection('tutors')
          .doc(widget.tutor.id)
          .get();
      final data = tutorDoc.data();

      if (data == null) {
        setState(() {
          _availableSlots = [];
          _loadingSlots = false;
        });
        return;
      }

      var slots = _generateSlotsForDay(date, _extractWeeklyAvailability(data));

      final now = DateTime.now();
      final isToday = date.year == now.year && date.month == now.month && date.day == now.day;

      if (isToday) {
        slots = slots.where((slotStr) {
          try {
            final parts = slotStr.split('|');
            final value = parts[0];
            final slotTime = DateFormat('HH:mm').parseLoose(value);
            final slotDateTime = DateTime(now.year, now.month, now.day, slotTime.hour, slotTime.minute);
            return slotDateTime.isAfter(now);
          } catch (_) {
            return true;
          }
        }).toList();
      }

      final querySnapshot = await FirebaseFirestore.instance
          .collection('sessions')
          .where('tutorId', isEqualTo: widget.tutor.id)
          .where('date', isEqualTo: dateStr)
          .where('status', whereIn: _blockingStatuses)
          .get();

      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      QuerySnapshot<Map<String, dynamic>>? studentQuerySnapshot;
      if (currentUserId != null) {
        studentQuerySnapshot = await FirebaseFirestore.instance
            .collection('sessions')
            .where('studentId', isEqualTo: currentUserId)
            .where('date', isEqualTo: dateStr)
            .where('status', whereIn: _blockingStatuses)
            .get();
      }

      final occupied = _occupiedSlotsForDate(
        slots,
        [
          ...querySnapshot.docs,
          ...?studentQuerySnapshot?.docs,
        ],
      );
      final available = _availableStartSlots(
        slots,
        occupied,
        _requiredSlotCount(),
      );

      setState(() {
        _allSlotValuesForSelectedDay = slots.map((entry) => entry.split('|')[0]).toList();
        _availableSlots = available;
        if (_selectedSlotIndex != null && _selectedSlotIndex! >= _availableSlots.length) {
          _selectedSlotIndex = null;
        }
      });
    } catch (_) {
      setState(() {
        _allSlotValuesForSelectedDay = [];
        _availableSlots = [];
        _selectedSlotIndex = null;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingSlots = false);
      }
    }
  }

  Future<void> _createBooking(
    BuildContext context,
    DateTime date,
    String slotValue,
    String slotDisplay,
  ) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final slotCount = _requiredSlotCount();
    final startIndex = _allSlotValuesForSelectedDay.indexOf(slotValue);
    if (startIndex == -1 || startIndex + slotCount > _allSlotValuesForSelectedDay.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The selected slot is no longer available.')),
      );
      return;
    }

    final sessionDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(slotValue.split(':')[0]),
      int.parse(slotValue.split(':')[1]),
    );

    if (sessionDateTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot book a session in the past')),
      );
      return;
    }

    final reservedSlots = _allSlotValuesForSelectedDay.sublist(startIndex, startIndex + slotCount);
    final docId = '${widget.tutor.id}_${dateStr}_${slotValue.replaceAll(':', '')}';

    Navigator.of(context).push(
      AppTransitions.slideFromRight(
        page: ManualPaymentScreen(
          sessionId: docId,
          tutorId: widget.tutor.id,
          subject: widget.tutor.subjects[_selectedSubjectIndex],
          date: dateStr,
          time: slotValue,
          timeDisplay: slotDisplay,
          sessionDateTime: sessionDateTime,
          amount: widget.tutor.hourlyRate * slotCount,
          durationMinutes: _selectedDurationMinutes,
          slotCount: slotCount,
          reservedSlots: reservedSlots,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final names = widget.tutor.name.split(' ');
    final initials = names.map((n) => n.isNotEmpty ? n[0] : '').take(2).join();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Tutor Profile'),
        actions: [
          IconButton(
            onPressed: () async {
              final currentUserId = FirebaseAuth.instance.currentUser?.uid;
              if (currentUserId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please log in to contact this tutor.')),
                );
                return;
              }

              // Calculate chatId alphabetically
              final chatId = MessagingService.instance.getChatId(currentUserId, widget.tutor.id);

              final authUser = FirebaseAuth.instance.currentUser;
              final studentName = authUser?.displayName ?? 'Student';
              final studentPhoto = authUser?.photoURL ?? '';

              // Fetch user profile from database to get correct details
              final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
              final displayName = userDoc.exists
                  ? (userDoc.data()?['name'] ?? userDoc.data()?['displayName'] ?? studentName)
                  : studentName;
              final photoURL = userDoc.exists
                  ? (userDoc.data()?['photoUrl'] ?? userDoc.data()?['profileImageUrl'] ?? studentPhoto)
                  : studentPhoto;

              final currentUserMeta = ChatParticipantMetadata(
                displayName: displayName,
                photoURL: photoURL,
              );

              final tutorMeta = ChatParticipantMetadata(
                displayName: widget.tutor.name,
                photoURL: widget.tutor.profileImageUrl ?? '',
              );

              if (!context.mounted) return;
              Navigator.of(context).push(
                AppTransitions.slideFromRight(
                  page: ZelpChatScreen(
                    chatId: chatId,
                    currentUserId: currentUserId,
                    otherUserId: widget.tutor.id,
                    currentUserMetadata: currentUserMeta,
                    otherUserMetadata: tutorMeta,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.chat_bubble_outline_rounded),
          ),
          IconButton(onPressed: () {}, icon: const Icon(Icons.bookmark_border)),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header details
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.fromBorderSide(AppTheme.border()),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 92,
                            height: 92,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              gradient: widget.tutor.profileImageUrl != null && widget.tutor.profileImageUrl!.isNotEmpty
                                  ? null
                                  : AppTheme.buttonGradient,
                              image: widget.tutor.profileImageUrl != null && widget.tutor.profileImageUrl!.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(widget.tutor.profileImageUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: widget.tutor.profileImageUrl != null && widget.tutor.profileImageUrl!.isNotEmpty
                                ? null
                                : Center(
                                    child: Text(
                                      initials.isNotEmpty ? initials : 'TR',
                                      style: const TextStyle(
                                        color: AppTheme.background,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.tutor.name,
                                  style: const TextStyle(
                                      fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded, size: 18, color: AppTheme.primary),
                                    const SizedBox(width: 4),
                                    Text(widget.tutor.rating.toStringAsFixed(1),
                                        style: const TextStyle(
                                            color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
                                    const SizedBox(width: 10),
                                    const Text('•'),
                                    const SizedBox(width: 10),
                                    Text('${widget.tutor.completedSessionsCount} sessions',
                                        style: const TextStyle(color: AppTheme.textSecondary)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  widget.tutor.bio,
                                  style: const TextStyle(color: AppTheme.textSecondary, height: 1.45),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (widget.tutor.subjects.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.tutor.subjects.map((s) => _SubjectChip(s)).toList(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Real Reviews Feed Section
                const Text('Reviews',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                const SizedBox(height: 12),
                StreamBuilder<List<ReviewModel>>(
                  stream: _reviewsRepository.tutorReviews(widget.tutor.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final reviews = snapshot.data ?? [];
                    if (reviews.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.fromBorderSide(AppTheme.border()),
                        ),
                        child: const Center(
                          child: Text(
                            'No student reviews yet.',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: reviews.map((review) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ReviewTile(
                            name: 'Verified Student',
                            text: review.reviewText,
                            rating: review.rating.toStringAsFixed(1),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Booking times
                const Text('Available times',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                const SizedBox(height: 12),

                // Calendar scroll tabs
                ZelpCalendarPicker(
                  dates: _dates,
                  selectedIndex: _selectedDateIndex,
                  onChanged: (value) {
                    setState(() {
                      _selectedDateIndex = value;
                      _selectedSlotIndex = null;
                    });
                    _loadSlotsForDate(_dates[value]);
                  },
                ),
                const SizedBox(height: 16),

                // Subject Selector choice chips
                if (widget.tutor.subjects.isNotEmpty) ...[
                  const Text('Select Subject', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(widget.tutor.subjects.length, (index) {
                      final active = index == _selectedSubjectIndex;
                      final s = widget.tutor.subjects[index];
                      return PressableScale(
                        onTap: () => setState(() => _selectedSubjectIndex = index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: active ? AppTheme.buttonGradient : null,
                            color: active ? null : AppTheme.surface,
                            borderRadius: BorderRadius.circular(999),
                            border: active ? null : Border.fromBorderSide(AppTheme.border()),
                          ),
                          child: Text(
                            s,
                            style: TextStyle(
                              color: active ? AppTheme.background : AppTheme.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                ],

                // Duration segmented button
                const Text('Duration', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment<int>(value: 60, label: Text('60 min')),
                    ButtonSegment<int>(value: 120, label: Text('120 min')),
                  ],
                  selected: <int>{_selectedDurationMinutes},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _selectedDurationMinutes = selection.first;
                      _selectedSlotIndex = null;
                    });
                    _loadSlotsForDate(_dates[_selectedDateIndex]);
                  },
                ),
                const SizedBox(height: 16),

                // Available Time Slots wrapped chips
                if (_loadingSlots)
                  const AppLoadingIndicator(message: 'Loading slots...')
                else if (_availableSlots.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No slots available for this date.', style: TextStyle(color: AppTheme.textSecondary)),
                  )
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: List.generate(_availableSlots.length, (index) {
                      final active = index == _selectedSlotIndex;
                      final s = _availableSlots[index];
                      final display = s.split('|')[1];
                      return PressableScale(
                        onTap: () => setState(() => _selectedSlotIndex = index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: active ? AppTheme.buttonGradient : null,
                            color: active ? null : AppTheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: active ? null : Border.fromBorderSide(AppTheme.border()),
                          ),
                          child: Text(
                            display,
                            style: TextStyle(
                              color: active ? AppTheme.background : AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                const SizedBox(height: 20),

                // Booking overview details
                const Text('Booking details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.fromBorderSide(AppTheme.border()),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.tutor.subjects.isNotEmpty)
                        _InfoRow(label: 'Subject', value: widget.tutor.subjects[_selectedSubjectIndex]),
                      const SizedBox(height: 10),
                      _InfoRow(label: 'Duration', value: '$_selectedDurationMinutes minutes'),
                      const SizedBox(height: 10),
                      _InfoRow(
                          label: 'Price',
                          value:
                              '\$${(widget.tutor.hourlyRate * (_selectedDurationMinutes == 120 ? 2 : 1)).toStringAsFixed(0)}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: ZelpPrimaryButton(
                label: 'Book Session',
                onTap: _selectedSlotIndex == null
                    ? null
                    : () async {
                        final s = _availableSlots[_selectedSlotIndex!];
                        final parts = s.split('|');
                        final value = parts[0];
                        final display = parts[1];
                        await _createBooking(context, _dates[_selectedDateIndex], value, display);
                      },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectChip extends StatelessWidget {
  const _SubjectChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.fromBorderSide(AppTheme.border()),
      ),
      child: Text(label, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.name, required this.text, required this.rating});
  final String name;
  final String text;
  final String rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.fromBorderSide(AppTheme.border()),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
              Row(
                children: [
                  const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(rating, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(text, style: const TextStyle(color: AppTheme.textSecondary, height: 1.4)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 90, child: Text(label, style: const TextStyle(color: AppTheme.textSecondary))),
        Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
