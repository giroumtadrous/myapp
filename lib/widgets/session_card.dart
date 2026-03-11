import 'package:flutter/material.dart';

class SessionCard extends StatelessWidget {
  final String tutorName;
  final String subject;
  final String date;
  final String timeRange;
  final String statusLabel;
  final Color statusColor;
  final bool isActive;

  /// Callback for opening a meeting link. If null, Join Meet is disabled.
  final VoidCallback? onJoinMeet;

  /// When non-null a "Cancel Session" button is shown for upcoming sessions.
  final VoidCallback? onCancel;

  /// When true the card is styled as a past/history card (no join button).
  final bool isPast;

  /// Callback fired when user taps the card body.
  final VoidCallback? onTap;

  const SessionCard({
    super.key,
    required this.tutorName,
    required this.subject,
    required this.date,
    required this.timeRange,
    required this.statusLabel,
    required this.statusColor,
    required this.isActive,
    this.onJoinMeet,
    this.onCancel,
    this.isPast = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  child: Icon(Icons.person, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tutorName,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subject,
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel.toUpperCase(),
                    style: textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 18),
                const SizedBox(width: 6),
                Text(date, style: textTheme.bodyMedium),
                const SizedBox(width: 16),
                const Icon(Icons.schedule_outlined, size: 18),
                const SizedBox(width: 6),
                Text(timeRange, style: textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: 16),
              if (!isPast) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onJoinMeet ?? (isActive ? () {} : null),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Join Session'),
                    ),
                  ),
                  if (onCancel != null) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onCancel,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          foregroundColor: Colors.red[700],
                          side: BorderSide(color: Colors.red[300]!),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ],
                ],
              ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
