import 'package:flutter/material.dart';
import 'package:myapp/constants/availability_constants.dart';

import '../../models/tutor_model.dart';
import '../../repositories/tutors_repository.dart';
import '../booking/booking_screen.dart';

class TutorProfileScreen extends StatelessWidget {
  final String tutorId;
  final TutorsRepository _tutorsRepository = TutorsRepository();

  TutorProfileScreen({
    super.key,
    required this.tutorId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tutor profile'),
      ),
      body: StreamBuilder<Tutor?>(
        stream: _tutorsRepository.getTutorById(tutorId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load tutor profile',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            );
          }

          final tutor = snapshot.data!;
          final textTheme = Theme.of(context).textTheme;

          // Debug logging
          debugPrint('TutorProfileScreen: Loaded tutor ${tutor.id}');
          debugPrint('TutorProfileScreen: weeklyAvailability = ${tutor.weeklyAvailability}');

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    child: Icon(
                      Icons.person,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tutor.name,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tutor.subjects.join(', '),
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: 20,
                        color: Colors.amber[600],
                  ),
                  const SizedBox(width: 4),
                      Text(
                        tutor.rating.toStringAsFixed(1),
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '\$${tutor.hourlyRate.toStringAsFixed(0)}/hr',
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'About',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tutor.bio,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BookingScreen(tutor: tutor),
                          ),
                        );
                      },
                      child: const Text('Book session'),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Calendar section showing only weeklyAvailability slots
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Available Hours',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (tutor.weeklyAvailability.isEmpty)
                    Text(
                      'No availability set',
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    )
                  else
                    ...daysOfWeek.map((day) {
                      final slots = tutor.weeklyAvailability[day] ?? [];
                      final dayName = dayDisplayNames[day] ?? day;
                      if (slots.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dayName + ':',
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                children: slots.map((hour) => Chip(
                                  label: Text(hour),
                                )).toList(),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

