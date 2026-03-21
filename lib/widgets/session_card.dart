import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'pressable_scale.dart';

class SessionCard extends StatefulWidget {
  final String tutorName;
  final String subject;
  final String date;
  final DateTime? sessionDateTime;
  final String timeRange;
  final String statusLabel;
  final Color statusColor;
  final bool isActive;
  final VoidCallback? onJoinMeet;
  final VoidCallback? onCancel;
  final bool isPast;
  final VoidCallback? onTap;
  final int? durationMinutes;

  const SessionCard({
    super.key,
    required this.tutorName,
    required this.subject,
    required this.date,
    this.sessionDateTime,
    required this.timeRange,
    required this.statusLabel,
    required this.statusColor,
    required this.isActive,
    this.onJoinMeet,
    this.onCancel,
    this.isPast = false,
    this.onTap,
    this.durationMinutes,
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
    final hasJoinAction = widget.onJoinMeet != null;
    final hasCancelAction = widget.onCancel != null;
    final personLabel = widget.tutorName.contains(':')
        ? widget.tutorName
        : 'Tutor: ${widget.tutorName}';
    final duration = widget.durationMinutes ?? 60;
    final isLongSession = duration >= 120;
    final lift = _pressed ? -1.0 : (_hovered ? -4.0 : 0.0);
    final elevation = _pressed ? 1.0 : (_hovered ? 5.0 : 2.0);
    final parsedDate = widget.sessionDateTime ?? _parseDisplayDate(widget.date);
    final day = parsedDate != null ? DateFormat('d').format(parsedDate) : '--';
    final month = parsedDate != null
      ? DateFormat('MMM').format(parsedDate).toUpperCase()
      : DateFormat('MMM').format(DateTime.now()).toUpperCase();
    final prettyDate = parsedDate != null ? DateFormat.yMMMd().format(parsedDate) : widget.date;
    final primaryColor = theme.colorScheme.primary;

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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16 + elevation,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: widget.onTap,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              day,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              month,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.7,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.timeRange,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                prettyDate,
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: widget.statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.statusLabel.toUpperCase(),
                          style: TextStyle(
                            color: widget.statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.subject,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isLongSession
                              ? const Color(0xFFFFF1D6)
                              : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Duration: $duration min',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isLongSession
                                ? const Color(0xFFB45309)
                                : const Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                      if (isLongSession) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.schedule,
                          size: 14,
                          color: Color(0xFFB45309),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE0E7FF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Color(0xFF4051B5),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          personLabel,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (!widget.isPast && (hasJoinAction || hasCancelAction))
                    Row(
                      children: [
                        if (hasJoinAction)
                          Expanded(
                            child: PressableScale(
                              child: ElevatedButton(
                                onPressed: widget.onJoinMeet,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4051B5),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text('Join Session'),
                              ),
                            ),
                          ),
                        if (hasJoinAction && hasCancelAction)
                          const SizedBox(width: 10),
                        if (hasCancelAction)
                          Expanded(
                            child: PressableScale(
                              child: OutlinedButton(
                                onPressed: widget.onCancel,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  foregroundColor: const Color(0xFF475569),
                                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                          ),
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

  DateTime? _parseDisplayDate(String value) {
    final direct = DateTime.tryParse(value);
    if (direct != null) return direct;

    final formats = <DateFormat>[
      DateFormat.yMMMd(),
      DateFormat('MMM d, y'),
      DateFormat('d MMM y'),
      DateFormat('yyyy-MM-dd'),
    ];

    for (final format in formats) {
      try {
        return format.parseStrict(value);
      } catch (_) {}
    }

    return null;
  }
}
