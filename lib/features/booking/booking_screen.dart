import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../models/tutor_model.dart';
import '../../utils/app_transitions.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/pressable_scale.dart';
import 'manual_payment_screen.dart';

class BookingScreen extends StatefulWidget {
  final Tutor tutor;

  const BookingScreen({super.key, required this.tutor});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedTime;
  int _selectedDurationMinutes = 60;

  List<String> _availableSlots = [];
  List<String> _allDaySlots = [];
  bool _loadingSlots = true;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _tutorDocSubscription;

  @override
  void initState() {
    super.initState();
    _listenToTutorAvailability();
    _loadAvailableSlots(_selectedDate);
  }

  void _listenToTutorAvailability() {
    _tutorDocSubscription = FirebaseFirestore.instance
        .collection('tutors')
        .doc(widget.tutor.id)
        .snapshots()
        .listen((snapshot) {
          if (!mounted || !snapshot.exists) return;
          _loadAvailableSlots(_selectedDate);
        });
  }

  Future<void> _loadAvailableSlots(DateTime date) async {
    setState(() {
      _loadingSlots = true;
    });

    try {
      final dayName = DateFormat('EEEE').format(date).toLowerCase();
      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      final tutorDoc = await FirebaseFirestore.instance
          .collection('tutors')
          .doc(widget.tutor.id)
          .get();

      final data = tutorDoc.data();

      final rawWeekly =
          data?['weeklyAvailability'] ?? data?['weekly_availability'];
      final weeklyAvailability = rawWeekly is Map
          ? Map<String, dynamic>.from(rawWeekly)
          : <String, dynamic>{};

      List<String> weeklySlots = List<String>.from(
        weeklyAvailability[dayName] ?? [],
      );
      weeklySlots.sort((a, b) {
        try {
          final aTime = DateFormat('HH:mm').parseLoose(a);
          final bTime = DateFormat('HH:mm').parseLoose(b);
          return aTime.compareTo(bTime);
        } catch (_) {
          return a.compareTo(b);
        }
      });

      // Filter out past times if the selected date is today
      final now = DateTime.now();
      final isToday = date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
      
      if (isToday) {
        weeklySlots = weeklySlots.where((slot) {
          try {
            final slotTime = DateFormat('HH:mm').parseLoose(slot);
            final slotDateTime = DateTime(now.year, now.month, now.day, 
                slotTime.hour, slotTime.minute);
            return slotDateTime.isAfter(now);
          } catch (_) {
            return true;
          }
        }).toList();
      }

      final bookingsSnap = await FirebaseFirestore.instance
          .collection('sessions')
          .where('tutorId', isEqualTo: widget.tutor.id)
          .where('date', isEqualTo: dateStr)
          .get();

      final bookedSlots = <String>{};
      for (final doc in bookingsSnap.docs) {
        final data = doc.data();
        final reservedRaw = data['reservedSlots'];
        if (reservedRaw is List && reservedRaw.isNotEmpty) {
          for (final slot in reservedRaw) {
            bookedSlots.add(slot.toString());
          }
          continue;
        }
        final time = (data['time'] ?? '').toString();
        if (time.isNotEmpty) bookedSlots.add(time);
      }

      final requiredSlots = _selectedDurationMinutes == 120 ? 2 : 1;
      final availableSlots = <String>[];
      for (int i = 0; i < weeklySlots.length; i++) {
        if (i + requiredSlots > weeklySlots.length) break;

        bool free = true;
        for (int offset = 0; offset < requiredSlots; offset++) {
          if (bookedSlots.contains(weeklySlots[i + offset])) {
            free = false;
            break;
          }
        }
        if (free) availableSlots.add(weeklySlots[i]);
      }

      setState(() {
        _allDaySlots = weeklySlots;
        _availableSlots = availableSlots;
        _selectedTime = availableSlots.isNotEmpty ? availableSlots.first : null;
        _loadingSlots = false;
      });
    } catch (e) {
      setState(() {
        _allDaySlots = [];
        _availableSlots = [];
        _loadingSlots = false;
      });
    }
  }

  @override
  void dispose() {
    _tutorDocSubscription?.cancel();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDate: _selectedDate,
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });

      _loadAvailableSlots(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Book session')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Tutor Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.08),
                        child: Icon(
                          Icons.person,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 16),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.tutor.name,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              widget.tutor.subjects.join(', '),
                              style: textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[700],
                              ),
                            ),

                            const SizedBox(height: 8),

                            Row(
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  size: 18,
                                  color: Colors.amber[600],
                                ),

                                const SizedBox(width: 4),

                                Text(
                                  widget.tutor.rating.toStringAsFixed(1),
                                  style: textTheme.bodyMedium,
                                ),

                                const SizedBox(width: 12),

                                Text(
                                  '\$${widget.tutor.hourlyRate.toStringAsFixed(0)}/hr',
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Session details',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 16),

              /// Date Picker
              Text('Date', style: textTheme.labelLarge),

              const SizedBox(height: 6),

              ListTile(
                title: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),

              const SizedBox(height: 16),

              /// Time Slots
              Text('Available Time', style: textTheme.labelLarge),

              const SizedBox(height: 6),

              if (_loadingSlots)
                const AppLoadingIndicator(message: 'Loading available slots...')
              else if (_availableSlots.isEmpty)
                const Text("No available slots for this date")
              else
                DropdownButtonFormField<String>(
                  initialValue: _selectedTime,
                  items: _availableSlots
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedTime = value;
                    });
                  },
                  decoration: const InputDecoration(hintText: 'Select a time'),
                ),

              const SizedBox(height: 16),
              Text('Duration', style: textTheme.labelLarge),
              const SizedBox(height: 6),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment<int>(value: 60, label: Text('60 min')),
                  ButtonSegment<int>(value: 120, label: Text('120 min')),
                ],
                selected: <int>{_selectedDurationMinutes},
                onSelectionChanged: (selection) {
                  setState(() {
                    _selectedDurationMinutes = selection.first;
                  });
                  _loadAvailableSlots(_selectedDate);
                },
              ),

              const SizedBox(height: 32),

              /// Confirm Button
              SizedBox(
                width: double.infinity,
                child: PressableScale(
                  child: ElevatedButton(
                    onPressed: _selectedTime == null
                        ? null
                        : () {
                            final date = DateFormat(
                              'yyyy-MM-dd',
                            ).format(_selectedDate);
                            final time = _selectedTime!;
                            
                            // Validate that the selected date/time is not in the past
                            try {
                              final bookingTime = DateFormat('HH:mm').parse(time);
                              final sessionDateTime = DateTime(
                                _selectedDate.year,
                                _selectedDate.month,
                                _selectedDate.day,
                                bookingTime.hour,
                                bookingTime.minute,
                              );
                              
                              if (sessionDateTime.isBefore(DateTime.now())) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Cannot book a session in the past'),
                                  ),
                                );
                                return;
                              }
                            } catch (_) {}
                            
                            final sessionId =
                                '${widget.tutor.id}_${date}_${time.replaceAll(':', '')}';
                            final timeDisplay = DateFormat.jm().format(
                              DateFormat('HH:mm').parse(time),
                            );
                            final slotCount =
                                _selectedDurationMinutes == 120 ? 2 : 1;
                            final startIndex = _allDaySlots.indexOf(time);
                            final reservedSlots =
                                startIndex >= 0 && startIndex + slotCount <= _allDaySlots.length
                                ? _allDaySlots.sublist(startIndex, startIndex + slotCount)
                                : <String>[time];

                            Navigator.of(context).push(
                              AppTransitions.slideFromRight(
                                page: ManualPaymentScreen(
                                  sessionId: sessionId,
                                  tutorId: widget.tutor.id,
                                  subject: widget.tutor.subjects.first,
                                  date: date,
                                  time: time,
                                  timeDisplay: timeDisplay,
                                  sessionDateTime: DateTime(
                                    _selectedDate.year,
                                    _selectedDate.month,
                                    _selectedDate.day,
                                    int.parse(time.split(':')[0]),
                                    int.parse(time.split(':')[1]),
                                  ),
                                  amount: widget.tutor.hourlyRate * slotCount,
                                  durationMinutes: _selectedDurationMinutes,
                                  slotCount: slotCount,
                                  reservedSlots: reservedSlots,
                                ),
                              ),
                            );
                          },
                    child: const Text('Confirm booking'),
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
