import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../../models/tutor_model.dart';
import '../../utils/app_transitions.dart';
import '../../utils/hero_tags.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/expertise_chip.dart';
import '../../widgets/pressable_scale.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/time_slot_button.dart';
import 'manual_payment_screen.dart';

class TutorBookingScreen extends StatefulWidget {
  final Tutor tutor;

  const TutorBookingScreen({super.key, required this.tutor});

  @override
  State<TutorBookingScreen> createState() => _TutorBookingScreenState();
}

class _TutorBookingScreenState extends State<TutorBookingScreen> {
  static const _reviewsCount = 124;

  int _selectedSubjectIndex = 0;
  late TextEditingController _notesController;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<String> _availableSlots = [];
  int? _selectedSlotIndex;
  bool _loadingSlots = false;
  // Dates (normalised to midnight) that have ≥1 available slot
  Set<DateTime> _daysWithSlots = {};
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _tutorDocSubscription;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
    _subscribeToTutorAvailability();
    // Pre-compute highlighted days for the current month
    _loadAvailableDays(_focusedDay);
  }

  void _subscribeToTutorAvailability() {
    _tutorDocSubscription = FirebaseFirestore.instance
        .collection('tutors')
        .doc(widget.tutor.id)
        .snapshots()
        .listen((snapshot) {
          if (!mounted || !snapshot.exists) return;
          _loadAvailableDays(_focusedDay);
          if (_selectedDay != null) {
            _loadSlotsForDate(_selectedDay!);
          }
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

  /// Fetches weekly availability from Firestore and computes which days in
  /// [month] still have at least one free slot (not already booked).
  Future<void> _loadAvailableDays(DateTime month) async {
    try {
      final tutorDoc = await FirebaseFirestore.instance
          .collection('tutors')
          .doc(widget.tutor.id)
          .get();
      final data = tutorDoc.data();
      if (data == null) return;

      final weekly = _extractWeeklyAvailability(data);
      if (weekly.isEmpty) return;

      // Collect all dates in the visible month
      final firstDay = DateTime(month.year, month.month, 1);
      final lastDay = DateTime(month.year, month.month + 1, 0);

      // Fetch all booked sessions for this tutor in this month
      final qs = await FirebaseFirestore.instance
          .collection('sessions')
          .where('tutorId', isEqualTo: widget.tutor.id)
          .where(
            'status',
            whereIn: [
              'pending',
              'confirmed',
              'booked',
              'pending_payment_verification',
            ],
          )
          .get();

      // Build a set of 'yyyy-MM-dd|HH:mm' strings that are occupied
      final occupiedSlots = <String>{};
      for (final doc in qs.docs) {
        final d = doc.data();
        final dateField = d['date']?.toString();
        final timeField = d['time']?.toString();
        if (dateField != null && timeField != null) {
          occupiedSlots.add('$dateField|$timeField');
        }
      }

      final available = <DateTime>{};
      DateTime cursor = firstDay;
      while (!cursor.isAfter(lastDay)) {
        final slots = _generateSlotsForDay(cursor, weekly);
        final dateStr = DateFormat('yyyy-MM-dd').format(cursor);
        final hasFree = slots.any((s) {
          final value = s.split('|')[0];
          return !occupiedSlots.contains('$dateStr|$value');
        });
        if (hasFree) {
          available.add(DateTime(cursor.year, cursor.month, cursor.day));
        }
        cursor = cursor.add(const Duration(days: 1));
      }

      setState(() => _daysWithSlots = available);
    } catch (_) {}
  }

  /// Pure helper — generates 'HH:mm|display' slot strings for [date] given the
  /// tutor's [weekly] availability map. No network calls.
  List<String> _generateSlotsForDay(
    DateTime date,
    Map<String, List<String>> weekly,
  ) {
    final weekdayName = DateFormat.EEEE().format(date).toLowerCase();
    final avail = weekly[weekdayName] ?? [];
    if (avail.isEmpty) return [];

    final slots = <String>[];
    for (final t in avail) {
      try {
        DateTime dt = DateFormat('HH:mm').parseLoose(t.toString());
        dt = DateTime(date.year, date.month, date.day, dt.hour, dt.minute);
        slots.add(
          '${DateFormat('HH:mm').format(dt)}|${DateFormat.jm().format(dt)}',
        );
      } catch (_) {}
    }
    return slots;
  }

  @override
  void dispose() {
    _tutorDocSubscription?.cancel();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadSlotsForDate(DateTime date) async {
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

      final weekly = _extractWeeklyAvailability(data);
      final slots = _generateSlotsForDay(date, weekly);

      // Query booked sessions for this tutor on the selected date
      final querySnapshot = await FirebaseFirestore.instance
          .collection('sessions')
          .where('tutorId', isEqualTo: widget.tutor.id)
          .where('date', isEqualTo: dateStr)
          .where(
            'status',
            whereIn: [
              'confirmed',
              'pending',
              'booked',
              'pending_payment_verification',
            ],
          )
          .get();

      final occupied = <String>{};
      for (final doc in querySnapshot.docs) {
        final d = doc.data();
        final time = d['time']?.toString();
        if (time != null) {
          try {
            occupied.add(
              DateFormat('HH:mm').format(DateFormat('HH:mm').parseLoose(time)),
            );
          } catch (_) {
            try {
              occupied.add(
                DateFormat('HH:mm').format(DateFormat.jm().parseLoose(time)),
              );
            } catch (_) {
              occupied.add(time);
            }
          }
        }
      }

      final available = slots
          .where((s) => !occupied.contains(s.split('|')[0]))
          .toList();

      setState(() => _availableSlots = available);
    } catch (e) {
      setState(() => _availableSlots = []);
    } finally {
      setState(() => _loadingSlots = false);
    }
  }

  Future<void> _createBooking(
    BuildContext context,
    DateTime date,
    String slotValue,
    String slotDisplay,
  ) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final docId =
        '${widget.tutor.id}_${dateStr}_${slotValue.replaceAll(':', '')}';
    final sessionDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(slotValue.split(':')[0]),
      int.parse(slotValue.split(':')[1]),
    );

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
          amount: widget.tutor.hourlyRate,
        ),
      ),
    );
  }

  Widget _buildCalendarSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose a Date',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        TableCalendar(
          firstDay: DateTime.now().subtract(const Duration(days: 365)),
          lastDay: DateTime.now().add(const Duration(days: 365)),
          focusedDay: _focusedDay,
          selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
          onDaySelected: (selected, focused) {
            setState(() {
              _selectedDay = selected;
              _focusedDay = focused;
              _selectedSlotIndex = null;
            });
            _loadSlotsForDate(selected);
          },
          onPageChanged: (focused) {
            setState(() => _focusedDay = focused);
            _loadAvailableDays(focused);
          },
          calendarFormat: CalendarFormat.month,
          // Mark days that have available slots with a green dot
          eventLoader: (day) {
            final normalised = DateTime(day.year, day.month, day.day);
            return _daysWithSlots.contains(normalised) ? [true] : [];
          },
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, day, events) {
              if (events.isEmpty) return const SizedBox.shrink();
              return Positioned(
                bottom: 4,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _selectedDay == null
              ? 'Select a date to see available times'
              : 'Available times - ${DateFormat.yMMMd().format(_selectedDay!)}',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        if (_loadingSlots)
          const AppLoadingIndicator(message: 'Loading available slots...')
        else if (_availableSlots.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No available slots for this date.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(_availableSlots.length, (i) {
              final s = _availableSlots[i];
              final parts = s.split('|');
              final display = parts[1];
              return TimeSlotButton(
                label: display,
                isSelected: _selectedSlotIndex == i,
                onTap: () {
                  setState(() {
                    _selectedSlotIndex = i;
                  });
                },
              );
            }),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Tutor Profile'),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.share_rounded), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TutorHeader(tutor: widget.tutor),
                  const SizedBox(height: 20),
                  _ActionButtons(tutor: widget.tutor),
                  const SizedBox(height: 20),
                  _StatsSection(
                    rating: widget.tutor.rating,
                    reviewsCount: _reviewsCount,
                  ),
                  const SizedBox(height: 20),
                  _PriceSection(price: widget.tutor.hourlyRate),
                  const SizedBox(height: 24),
                  _AboutSection(aboutText: widget.tutor.bio),
                  const SizedBox(height: 24),
                  _ExpertiseSection(
                    expertiseList: widget.tutor.subjects,
                    selectedIndex: _selectedSubjectIndex,
                    onSubjectSelected: (index) {
                      setState(() => _selectedSubjectIndex = index);
                    },
                  ),
                  const SizedBox(height: 24),
                  _NotesSection(notesController: _notesController),
                  const SizedBox(height: 24),
                  _buildCalendarSection(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          _BottomBookingBar(
            price: widget.tutor.hourlyRate,
            onConfirm: () async {
              if (_selectedDay == null || _selectedSlotIndex == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please select a date and time slot.'),
                  ),
                );
                return;
              }
              final s = _availableSlots[_selectedSlotIndex!];
              final parts = s.split('|');
              final value = parts[0];
              final display = parts[1];
              await _createBooking(context, _selectedDay!, value, display);
            },
          ),
        ],
      ),
    );
  }
}

class _TutorHeader extends StatelessWidget {
  final Tutor tutor;

  const _TutorHeader({required this.tutor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Column(
      children: [
        CircleAvatar(
          radius: 48,
          backgroundColor: Colors.transparent,
          child: Hero(
            tag: tutorAvatarHeroTag(tutor.id),
            child: CircleAvatar(
              radius: 48,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
              child: Icon(
                Icons.person,
                size: 56,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          tutor.name,
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          '${tutor.subjects.join(', ')} Specialist',
          style: textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.amber[50],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.amber[300]!),
          ),
          child: Text(
            'TOP RATED TUTOR',
            style: textTheme.labelSmall?.copyWith(
              color: Colors.amber[800],
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final Tutor tutor;

  const _ActionButtons({required this.tutor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: PressableScale(
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Book Session'),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: PressableScale(
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withOpacity(0.06),
              ),
              child: const Text('Message'),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsSection extends StatelessWidget {
  final double rating;
  final int reviewsCount;

  const _StatsSection({required this.rating, required this.reviewsCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        StatCard(
          leading: Icon(Icons.star_rounded, color: Colors.amber[600], size: 28),
          value: rating.toStringAsFixed(1),
          label: 'Rating',
        ),
        const SizedBox(width: 12),
        StatCard(
          leading: Icon(
            Icons.rate_review_outlined,
            color: Theme.of(context).colorScheme.primary,
            size: 24,
          ),
          value: reviewsCount.toString(),
          label: 'Reviews',
        ),
      ],
    );
  }
}

class _PriceSection extends StatelessWidget {
  final double price;

  const _PriceSection({required this.price});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '\$${price.toStringAsFixed(0)}',
            style: textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'PER HOUR',
            style: textTheme.labelMedium?.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  final String aboutText;

  const _AboutSection({required this.aboutText});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Text(
          aboutText,
          style: textTheme.bodyMedium?.copyWith(
            color: Colors.grey[800],
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

class _ExpertiseSection extends StatelessWidget {
  final List<String> expertiseList;
  final int selectedIndex;
  final ValueChanged<int> onSubjectSelected;

  const _ExpertiseSection({
    required this.expertiseList,
    required this.selectedIndex,
    required this.onSubjectSelected,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Subject for This Session',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: expertiseList
              .asMap()
              .entries
              .map(
                (e) => GestureDetector(
                  onTap: () => onSubjectSelected(e.key),
                  child: ExpertiseChip(
                    label: e.value,
                    isSelected: e.key == selectedIndex,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _NotesSection extends StatelessWidget {
  final TextEditingController notesController;

  const _NotesSection({required this.notesController});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add Notes for Tutor',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: notesController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Share any specific topics, goals, or questions...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }
}

class _BottomBookingBar extends StatelessWidget {
  final double price;
  final VoidCallback onConfirm;

  const _BottomBookingBar({required this.price, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Hourly Rate',
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '\$${price.toStringAsFixed(2)}',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              Expanded(
                child: PressableScale(
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Confirm Booking'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
