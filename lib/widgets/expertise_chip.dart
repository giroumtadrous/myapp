import 'package:flutter/material.dart';

class ExpertiseChip extends StatelessWidget {
  final String label;
  final bool isSelected;

  const ExpertiseChip({
    super.key,
    required this.label,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final backgroundColor =
        isSelected ? colorScheme.primary.withValues(alpha: 0.12) : Colors.grey[100];
    final textColor = isSelected ? colorScheme.primary : Colors.grey[800];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isSelected ? colorScheme.primary : Colors.transparent,
        ),
      ),
      child: Text(
        label,
        style: textTheme.bodyMedium?.copyWith(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}
