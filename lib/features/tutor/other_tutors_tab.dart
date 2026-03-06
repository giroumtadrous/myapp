import 'package:flutter/material.dart';

import '../../models/tutor_model.dart';
import '../../repositories/tutors_repository.dart';

class OtherTutorsTab extends StatelessWidget {
  final String currentTutorId;
  final TutorsRepository _tutorsRepository = TutorsRepository();

  OtherTutorsTab({
    required this.currentTutorId,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return StreamBuilder<List<Tutor>>(
      stream: _tutorsRepository.getTutors(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        var tutors = snapshot.data ?? [];

        // Filter out the current tutor
        tutors = tutors.where((t) => t.id != currentTutorId).toList();

        if (tutors.isEmpty) {
          return Center(
            child: Text(
              'No other tutors available',
              style: textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tutors.length,
          itemBuilder: (context, index) {
            final tutor = tutors[index];
            return _TutorCard(tutor: tutor);
          },
        );
      },
    );
  }
}

class _TutorCard extends StatelessWidget {
  final Tutor tutor;

  const _TutorCard({required this.tutor});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tutor.name,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (tutor.rating > 0)
                        Row(
                          children: [
                            const Icon(Icons.star, size: 16, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              tutor.rating.toStringAsFixed(1),
                              style: textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '\$${tutor.hourlyRate.toStringAsFixed(2)}/hr',
                    style: textTheme.labelSmall?.copyWith(
                      color: Colors.green[800],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (tutor.bio.isNotEmpty)
              Text(
                tutor.bio,
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.grey[700],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (tutor.bio.isNotEmpty) const SizedBox(height: 12),
            if (tutor.subjects.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tutor.subjects
                    .take(5)
                    .map(
                      (subject) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.indigo[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          subject,
                          style: textTheme.labelSmall?.copyWith(
                            color: Colors.indigo[800],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            if (tutor.subjects.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '+${tutor.subjects.length - 5} more subjects',
                  style: textTheme.labelSmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
