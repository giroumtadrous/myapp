import 'package:flutter/material.dart';

import '../models/tutor_model.dart';
import '../utils/hero_tags.dart';

class TutorCard extends StatefulWidget {
  final Tutor tutor;
  final VoidCallback onTap;
  final List<String>? visibleSubjects;

  const TutorCard({
    super.key,
    required this.tutor,
    required this.onTap,
    this.visibleSubjects,
  });

  @override
  State<TutorCard> createState() => _TutorCardState();
}

class _TutorCardState extends State<TutorCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final lift = _pressed ? -1.0 : (_hovered ? -4.0 : 0.0);
    final elevation = _pressed ? 1.5 : (_hovered ? 6.0 : 3.0);

    return SizedBox(
      width: 220,
      child: MouseRegion(
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
            clipBehavior: Clip.antiAlias,
            elevation: elevation,
            shadowColor: Colors.black.withOpacity(0.06),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: widget.onTap,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapCancel: () => setState(() => _pressed = false),
              onTapUp: (_) => setState(() => _pressed = false),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        Hero(
                          tag: tutorAvatarHeroTag(widget.tutor.id),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.07),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(18),
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.person,
                                size: 56,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.65),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  size: 16,
                                  color: Colors.amber[400],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.tutor.rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.tutor.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (widget.visibleSubjects ?? widget.tutor.subjects)
                              .join(', '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '\$${widget.tutor.hourlyRate.toStringAsFixed(0)}/hr',
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
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
