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
    final hasJoinAction = widget.onJoinMeet != null;
    final hasCancelAction = widget.onCancel != null;
    final personLabel = widget.tutorName.contains(':')
        ? widget.tutorName
        : 'Tutor: ${widget.tutorName}';
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
          margin: const EdgeInsets.only(bottom: 14),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: widget.statusColor.withOpacity(0.12),
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
                      const Spacer(),
                      Text(
                        '${widget.date} • ${widget.timeRange}',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
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
}
