import 'package:flutter/material.dart';

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
  final List<String> _dates = const [
    'Today',
    'Tomorrow',
    'This Friday',
    'Next Monday',
  ];

  final List<String> _timeSlots = const [
    '10:00 AM',
    '2:00 PM',
    '5:00 PM',
    '8:00 PM',
  ];

  String? _selectedDate;
  String? _selectedTime;

  @override
  void initState() {
    super.initState();
    _selectedDate = _dates.first;
    _selectedTime = _timeSlots.first;
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
              Text(
                'Date',
                style: textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedDate,
                items: _dates
                    .map(
                      (d) => DropdownMenuItem(
                        value: d,
                        child: Text(d),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedDate = value;
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Select a date',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Time',
                style: textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedTime,
                items: _timeSlots
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
              const SizedBox(height: 24),
              Text(
                'You will only be charged after the session. A Google Meet link will be generated once backend integration is added.',
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.grey[700],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ConfirmationScreen(
                          tutor: widget.tutor,
                          date: _selectedDate ?? _dates.first,
                          time: _selectedTime ?? _timeSlots.first,
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

