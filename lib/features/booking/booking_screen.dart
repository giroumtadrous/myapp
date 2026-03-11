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

  List<String> _availableSlots = [];
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

      final bookingsSnap = await FirebaseFirestore.instance
          .collection('sessions')
          .where('tutorId', isEqualTo: widget.tutor.id)
          .where('date', isEqualTo: dateStr)
          .get();

      final bookedSlots = bookingsSnap.docs
          .map((d) => d['time'] as String)
          .toList();

      final availableSlots = weeklySlots
          .where((slot) => !bookedSlots.contains(slot))
          .toList();

      setState(() {
        _availableSlots = availableSlots;
        _selectedTime = availableSlots.isNotEmpty ? availableSlots.first : null;
        _loadingSlots = false;
      });
    } catch (e) {
      setState(() {
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
                            final sessionId =
                                '${widget.tutor.id}_${date}_${time.replaceAll(':', '')}';
                            final timeDisplay = DateFormat.jm().format(
                              DateFormat('HH:mm').parse(time),
                            );

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
                                  amount: widget.tutor.hourlyRate,
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
