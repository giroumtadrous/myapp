import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../../models/tutor_model.dart';
import '../../widgets/expertise_chip.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/time_slot_button.dart';
import 'confirmation_screen.dart';

class TutorBookingScreen extends StatefulWidget {
  final Tutor tutor;

  const TutorBookingScreen({
    super.key,
    required this.tutor,
  });

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
  bool _loadingSlots = false;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadSlotsForDate(DateTime date) async {
    setState(() => _loadingSlots = true);

    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    try {
      // Read tutor document for weekly availability
      final tutorDoc = await FirebaseFirestore.instance.collection('tutors').doc(widget.tutor.id).get();
      final data = tutorDoc.data();

      // Support multiple availability shapes. Expecting a map like:
      // { 'monday': { 'start': '09:00', 'end': '17:00', 'slotDuration': 60 }, ... }
      Map<String, dynamic>? weekly = (data != null && data['weekly_availability'] is Map)
          ? Map<String, dynamic>.from(data['weekly_availability'] as Map)
          : null;

      // get availability for this weekday
      final weekdayName = DateFormat.EEEE().format(date).toLowerCase();
      Map<String, dynamic>? avail;
      if (weekly != null) {
        if (weekly.containsKey(weekdayName)) {
          avail = Map<String, dynamic>.from(weekly[weekdayName] as Map);
        } else if (weekly.containsKey(date.weekday.toString())) {
          avail = Map<String, dynamic>.from(weekly[date.weekday.toString()] as Map);
        }
      }

      List<String> slots = [];
      if (avail != null) {
        final start = avail['start']?.toString();
        final end = avail['end']?.toString();
        final duration = (avail['slotDuration'] ?? avail['slot_duration'] ?? 60);
        final slotDuration = int.tryParse(duration.toString()) ?? 60;

        if (start != null && end != null) {
          // parse times as HH:mm
          DateTime startDt = DateFormat('HH:mm').parseLoose(start);
          DateTime endDt = DateFormat('HH:mm').parseLoose(end);

          // assign to the selected date
          startDt = DateTime(date.year, date.month, date.day, startDt.hour, startDt.minute);
          endDt = DateTime(date.year, date.month, date.day, endDt.hour, endDt.minute);

          DateTime cur = startDt;
          while (cur.add(Duration(minutes: slotDuration)).isBefore(endDt) || cur.add(Duration(minutes: slotDuration)).isAtSameMomentAs(endDt)) {
            final value = DateFormat('HH:mm').format(cur);
            final display = DateFormat.jm().format(cur);
            slots.add('$value|$display');
            cur = cur.add(Duration(minutes: slotDuration));
          }
        }
      }

      // Query bookings for this tutor on the selected date
      final bookingsSnap = await FirebaseFirestore.instance
          .collection('bookings')
          .where('tutorId', isEqualTo: widget.tutor.id)
          .where('date', isEqualTo: dateStr)
          .get();

      final occupied = <String>{};
      for (final doc in bookingsSnap.docs) {
        final status = (doc.data()['status'] ?? '').toString().toLowerCase();
        if (status == 'confirmed' || status == 'pending') {
          final time = doc.data()['time']?.toString() ?? '';
          // normalize to HH:mm if possible
          try {
            final parsed = DateFormat.jm().parseLoose(time);
            final normalized = DateFormat('HH:mm').format(parsed);
            occupied.add(normalized);
          } catch (_) {
            // fallback: accept direct value
            occupied.add(time);
          }
        }
      }

      final available = <String>[];
      for (final s in slots) {
        final parts = s.split('|');
        final value = parts[0];
        final display = parts[1];
        if (!occupied.contains(value)) {
          available.add('$value|$display');
        }
      }

      setState(() {
        _availableSlots = available.map((e) => e).toList();
      });
    } catch (e) {
      // on error, clear slots
      setState(() => _availableSlots = []);
    } finally {
      setState(() => _loadingSlots = false);
    }
  }

  Future<void> _createBooking(BuildContext context, DateTime date, String slotValue, String slotDisplay) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final docId = '${widget.tutor.id}_${dateStr}_${slotValue.replaceAll(':', '')}';

    final docRef = FirebaseFirestore.instance.collection('bookings').doc(docId);

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final existing = await tx.get(docRef);
        if (existing.exists) {
          throw Exception('Slot already booked');
        }

        final user = FirebaseAuth.instance.currentUser;

        tx.set(docRef, {
          'tutorId': widget.tutor.id,
          'studentId': user?.uid ?? '',
          'date': dateStr,
          'time': slotValue,
          'timeDisplay': slotDisplay,
          'subject': widget.tutor.subjects[_selectedSubjectIndex],
          'notes': _notesController.text,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'hourlyRate': widget.tutor.hourlyRate,
        });
      });

      // on success navigate to confirmation
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ConfirmationScreen(
            tutor: widget.tutor,
            date: DateFormat.yMMMMd().format(date),
            time: slotDisplay,
            selectedSubject: widget.tutor.subjects[_selectedSubjectIndex],
            notes: _notesController.text,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create booking: ${e.toString()}')),
      );
      // reload slots to reflect any change
      await _loadSlotsForDate(date);
    }
  }

  Widget _buildCalendarSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose a Date',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
            });
            _loadSlotsForDate(selected);
          },
          calendarFormat: CalendarFormat.month,
        ),
        const SizedBox(height: 12),
        Text(
          _selectedDay == null
              ? 'Select a date to see available times'
              : 'Available times - ${DateFormat.yMMMd().format(_selectedDay!)}',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: Colors.grey[800]),
        ),
        const SizedBox(height: 12),
        if (_loadingSlots)
          const Center(child: CircularProgressIndicator())
        else if (_availableSlots.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('No available slots for this date.', style: Theme.of(context).textTheme.bodyMedium),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _availableSlots.map((s) {
              final parts = s.split('|');
              final value = parts[0];
              final display = parts[1];
              return TimeSlotButton(
                label: display,
                isSelected: false,
                onTap: () async {
                  if (_selectedDay == null) return;
                  await _createBooking(context, _selectedDay!, value, display);
                },
              );
            }).toList(),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    /*final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
*/
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Tutor Profile'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () {},
          ),
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
            onConfirm: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ConfirmationScreen(
                    tutor: widget.tutor,
                    date: _selectedDay != null ? DateFormat.yMMMMd().format(_selectedDay!) : 'N/A',
                    time: 'N/A',
                    selectedSubject: widget.tutor.subjects[_selectedSubjectIndex],
                    notes: _notesController.text,
                  ),
                ),
              );
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
          backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
          child: Icon(
            Icons.person,
            size: 56,
            color: theme.colorScheme.primary,
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
          style: textTheme.bodyMedium?.copyWith(
            color: Colors.grey[700],
          ),
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
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .primary
                  .withOpacity(0.06),
            ),
            child: const Text('Message'),
          ),
        ),
      ],
    );
  }
}

class _StatsSection extends StatelessWidget {
  final double rating;
  final int reviewsCount;

  const _StatsSection({
    required this.rating,
    required this.reviewsCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        StatCard(
          leading: Icon(
            Icons.star_rounded,
            color: Colors.amber[600],
            size: 28,
          ),
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
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
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
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
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
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
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

class _AvailabilitySection extends StatelessWidget {
  final String monthLabel;
  final List<String> weekDates;
  final List<String> timeSlots;
  final int selectedDateIndex;
  final int selectedTimeIndex;
  final ValueChanged<int> onDateSelected;
  final ValueChanged<int> onTimeSelected;

  const _AvailabilitySection({
    required this.monthLabel,
    required this.weekDates,
    required this.timeSlots,
    required this.selectedDateIndex,
    required this.selectedTimeIndex,
    required this.onDateSelected,
    required this.onTimeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Availability',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              monthLabel,
              style: textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: weekDates.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final isSelected = index == selectedDateIndex;
              return GestureDetector(
                onTap: () => onDateSelected(index),
                child: Container(
                  width: 72,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primary
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? colorScheme.primary
                          : Colors.grey.shade300,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: colorScheme.primary.withOpacity(0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ],
                  ),
                  child: Center(
                    child: Text(
                      weekDates[index],
                      style: textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : Colors.grey[800],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Available Times - ${weekDates[selectedDateIndex]}',
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var i = 0; i < timeSlots.length; i++)
              TimeSlotButton(
                label: timeSlots[i],
                isSelected: i == selectedTimeIndex,
                onTap: () => onTimeSelected(i),
              ),
          ],
        ),
      ],
    );
  }
}

class _BottomBookingBar extends StatelessWidget {
  final double price;
  final VoidCallback onConfirm;

  const _BottomBookingBar({
    required this.price,
    required this.onConfirm,
  });

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
            ],
          ),
        ),
      ),
    );
  }
}
