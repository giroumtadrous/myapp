import 'package:flutter/material.dart';

class BookingsScreen extends StatelessWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final bookings = [
      {
        'tutor': 'Sarah Lee',
        'subject': 'Calculus',
        'date': 'Tomorrow',
        'time': '10:00 AM',
      },
      {
        'tutor': 'James Miller',
        'subject': 'Physics',
        'date': 'This Friday',
        'time': '2:00 PM',
      },
      {
        'tutor': 'Priya Patel',
        'subject': 'Computer Science',
        'date': 'Next Monday',
        'time': '5:00 PM',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('My bookings'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Upcoming sessions',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: bookings.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final booking = bookings[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking['tutor'] as String,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              booking['subject'] as String,
                              style: textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  booking['date'] as String,
                                  style: textTheme.bodyMedium,
                                ),
                                const SizedBox(width: 16),
                                const Icon(
                                  Icons.schedule_outlined,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  booking['time'] as String,
                                  style: textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

