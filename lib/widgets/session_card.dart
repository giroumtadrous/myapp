import 'package:flutter/material.dart';

import 'pressable_scale.dart';

class SessionCard extends StatefulWidget {
  final String tutorName;
  final String subject;
  final String date;
  final String timeRange;
  final String statusLabel;
  final Color statusColor;
  final bool isActive;
  final VoidCallback? onJoinMeet;
  final VoidCallback? onCancel;
  final bool isPast;
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
  State<SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<SessionCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final lift = _pressed ? -1.0 : (_hovered ? -4.0 : 0.0);
    final elevation = _pressed ? 1.0 : (_hovered ? 5.0 : 2.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: lift),
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Transform.translate(offset: Offset(0, value), child: child);
        },
        child: Card(
          elevation: elevation,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onTap,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: theme.colorScheme.primary.withOpacity(
                          0.1,
                        ),
                        child: Icon(
                          Icons.person,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.tutorName,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.subject,
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
                          color: widget.statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.statusLabel.toUpperCase(),
                          style: textTheme.labelSmall?.copyWith(
                            color: widget.statusColor,
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
                      Text(widget.date, style: textTheme.bodyMedium),
                      const SizedBox(width: 16),
                      const Icon(Icons.schedule_outlined, size: 18),
                      const SizedBox(width: 6),
                      Text(widget.timeRange, style: textTheme.bodyMedium),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (!widget.isPast)
                    Row(
                      children: [
                        Expanded(
                          child: PressableScale(
                            child: ElevatedButton(
                              onPressed:
                                  widget.onJoinMeet ??
                                  (widget.isActive ? () {} : null),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: const Text('Join Session'),
                            ),
                          ),
                        ),
                        if (widget.onCancel != null) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: PressableScale(
                              child: OutlinedButton(
                                onPressed: widget.onCancel,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  foregroundColor: Colors.red[700],
                                  side: BorderSide(color: Colors.red[300]!),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
