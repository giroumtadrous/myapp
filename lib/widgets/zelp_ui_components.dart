import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'pressable_scale.dart';

class ZelpPrimaryButton extends StatelessWidget {
  const ZelpPrimaryButton({super.key, required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.buttonGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.glow(alpha: 0.24),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: AppTheme.background, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppTheme.background,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
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

class ZelpSecondaryButton extends StatelessWidget {
  const ZelpSecondaryButton({super.key, required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.fromBorderSide(AppTheme.border()),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: AppTheme.primary, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
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

class ZelpOutlineButton extends StatelessWidget {
  const ZelpOutlineButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(onPressed: onTap, child: Text(label));
  }
}

class ZelpSearchBar extends StatelessWidget {
  const ZelpSearchBar({super.key, required this.hintText, this.onChanged, this.controller, this.onFilterTap});

  final String hintText;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final VoidCallback? onFilterTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hintText,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: onFilterTap == null
                  ? null
                  : IconButton(
                      onPressed: onFilterTap,
                      icon: const Icon(Icons.tune_outlined),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class ZelpCategoryTabs extends StatelessWidget {
  const ZelpCategoryTabs({super.key, required this.items, required this.selectedIndex, required this.onChanged});

  final List<String> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final active = selectedIndex == index;
          return PressableScale(
            onTap: () => onChanged(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                gradient: active ? AppTheme.buttonGradient : null,
                color: active ? null : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: active ? null : Border.fromBorderSide(AppTheme.border()),
              ),
              child: Text(
                items[index],
                style: TextStyle(
                  color: active ? AppTheme.background : AppTheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ZelpRatingBadge extends StatelessWidget {
  const ZelpRatingBadge({super.key, required this.rating});

  final String rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: AppTheme.buttonGradient,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        rating,
        style: const TextStyle(
          color: AppTheme.background,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class ZelpTutorCardData {
  const ZelpTutorCardData({
    required this.photoLabel,
    required this.name,
    required this.subject,
    required this.rating,
    required this.description,
    required this.price,
    required this.availability,
  });

  final String photoLabel;
  final String name;
  final String subject;
  final String rating;
  final String description;
  final String price;
  final String availability;
}

class ZelpTutorCard extends StatelessWidget {
  const ZelpTutorCard({super.key, required this.data, required this.onTap});

  final ZelpTutorCardData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.fromBorderSide(AppTheme.border()),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 100,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.fromBorderSide(AppTheme.border()),
                  ),
                  child: Center(
                    child: Text(
                      data.photoLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                Positioned(top: 8, right: 8, child: ZelpRatingBadge(rating: data.rating)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              data.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              data.subject,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4),
            ),
            const SizedBox(height: 6),
            Text(
              data.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.35),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    data.price,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.fromBorderSide(AppTheme.border()),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          data.availability,
                          style: const TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ZelpSessionCardData {
  const ZelpSessionCardData({
    required this.tutorName,
    required this.subject,
    required this.time,
    required this.duration,
    required this.status,
    required this.day,
    required this.month,
    required this.joinLabel,
    required this.secondaryLabel,
    this.enabled = true,
  });

  final String tutorName;
  final String subject;
  final String time;
  final String duration;
  final String status;
  final String day;
  final String month;
  final String joinLabel;
  final String secondaryLabel;
  final bool enabled;
}

class ZelpSessionCard extends StatelessWidget {
  const ZelpSessionCard({super.key, required this.data, this.onPrimaryTap, this.onSecondaryTap});

  final ZelpSessionCardData data;
  final VoidCallback? onPrimaryTap;
  final VoidCallback? onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: data.enabled ? 1 : 0.65,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.fromBorderSide(AppTheme.border()),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.fromBorderSide(AppTheme.border()),
                  ),
                  child: Column(
                    children: [
                      Text(data.day, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(data.month, style: const TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data.subject, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 5),
                      Text('${data.time} • ${data.duration}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(data.tutorName, style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: AppTheme.primary.withValues(alpha: 0.1),
                  ),
                  child: Text(
                    data.status.toUpperCase(),
                    style: const TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ZelpSecondaryButton(label: data.secondaryLabel, onTap: data.enabled ? onSecondaryTap : null),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ZelpPrimaryButton(label: data.joinLabel, onTap: data.enabled ? onPrimaryTap : null),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ZelpCalendarPicker extends StatelessWidget {
  const ZelpCalendarPicker({super.key, required this.dates, required this.selectedIndex, required this.onChanged});

  final List<DateTime> dates;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final date = dates[index];
          final active = index == selectedIndex;
          return PressableScale(
            onTap: () => onChanged(index),
            child: Container(
              width: 66,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: active ? AppTheme.buttonGradient : null,
                color: active ? null : AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: active ? null : Border.fromBorderSide(AppTheme.border()),
              ),
              child: Column(
                children: [
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      color: active ? AppTheme.background : AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _monthLabel(date.month),
                    style: TextStyle(
                      color: active ? AppTheme.background : AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _monthLabel(int month) {
    const labels = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return labels[month - 1];
  }
}
