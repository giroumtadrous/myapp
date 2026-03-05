import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../models/tutor_model.dart';
import 'confirmation_screen.dart';

class BookingScreen extends StatefulWidget {
  final Tutor tutor;

  const BookingScreen({
    super.key,
    required this.tutor,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {

  DateTime _selectedDate = DateTime.now();
  String? _selectedTime;

  List<String> _availableSlots = [];
  bool _loadingSlots = true;

  @override
  void initState() {
    super.initState();
    _loadAvailableSlots(_selectedDate);
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

      Map weeklyAvailability = data?['weekly_availability'] ?? {};

      List<String> weeklySlots =
          List<String>.from(weeklyAvailability[dayName] ?? []);

      final bookingsSnap = await FirebaseFirestore.instance
          .collection('sessions')
          .where('tutorId', isEqualTo: widget.tutor.id)
          .where('date', isEqualTo: dateStr)
          .get();

      final bookedSlots =
          bookingsSnap.docs.map((d) => d['time'] as String).toList();

      final availableSlots =
          weeklySlots.where((slot) => !bookedSlots.contains(slot)).toList();

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
      appBar: AppBar(
        title: const Text('Book session'),
      ),
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
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.08),
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
              Text(
                'Date',
                style: textTheme.labelLarge,
              ),

              const SizedBox(height: 6),

              ListTile(
                title: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),

              const SizedBox(height: 16),

              /// Time Slots
              Text(
                'Available Time',
                style: textTheme.labelLarge,
              ),

              const SizedBox(height: 6),

              if (_loadingSlots)
                const Center(child: CircularProgressIndicator())

              else if (_availableSlots.isEmpty)
                const Text("No available slots for this date")

              else
                DropdownButtonFormField<String>(
                  value: _selectedTime,
                  items: _availableSlots
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(t),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedTime = value;
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: 'Select a time',
                  ),
                ),

              const SizedBox(height: 32),

              /// Confirm Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedTime == null
                      ? null
                      : () {

                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ConfirmationScreen(
                                tutor: widget.tutor,
                                date: DateFormat('yyyy-MM-dd')
                                    .format(_selectedDate),
                                time: _selectedTime!,
                                selectedSubject: widget.tutor.subjects.first,
                                notes: '',
                              ),
                            ),
                          );

                        },
                  child: const Text('Confirm booking'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}