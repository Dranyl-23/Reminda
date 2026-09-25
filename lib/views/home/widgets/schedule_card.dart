import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/time_utils.dart';
import '../../../models/schedule_category.dart';
import '../../../models/schedule_entry.dart';
import '../../calendar/widgets/weekly_timetable_grid.dart';

class ScheduleCard extends StatelessWidget {
  final ScheduleEntry entry;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onToggleActive;
  final VoidCallback? onDelete;

  const ScheduleCard({
    super.key,
    required this.entry,
    this.onTap,
    this.onToggleActive,
    this.onDelete,
  });

  IconData _getIconForSubject(String title, ScheduleCategory category) {
    final lower = title.toLowerCase();
    if (lower.contains('program') || lower.contains('code') || lower.contains('cs') || lower.contains('it') || lower.contains('software')) {
      return Icons.computer_rounded;
    }
    if (lower.contains('math') || lower.contains('calc') || lower.contains('stat') || lower.contains('algebra')) {
      return Icons.calculate_rounded;
    }
    if (lower.contains('data') || lower.contains('db') || lower.contains('sql') || lower.contains('network')) {
      return Icons.storage_rounded;
    }
    if (lower.contains('free') || lower.contains('break') || lower.contains('lunch') || lower.contains('vacant')) {
      return Icons.coffee_rounded;
    }
    if (lower.contains('duty') || lower.contains('medic') || lower.contains('nurs') || lower.contains('hospital')) {
      return Icons.medical_services_rounded;
    }
    return category.icon;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = TimetableTheme.forTitle(entry.title, isDark);
    final subjectIcon = _getIconForSubject(entry.title, entry.category);

    final now = DateTime.now();
    final currentWeekday = now.weekday;
    final currentMinutes = now.hour * 60 + now.minute;
    final yesterdayDate = now.subtract(const Duration(days: 1));
    final yesterdayWeekday = currentWeekday == 1 ? 7 : currentWeekday - 1;
    final bool isMutedNext = entry.isNextOccurrenceMuted;
    bool isOngoing = false;

    // Check: did this shift start YESTERDAY and is still ongoing now?
    if (!isOngoing &&
        entry.spansNextDay &&
        entry.daysOfWeek.contains(yesterdayWeekday) &&
        !entry.isMutedOnDate(yesterdayDate)) {
      final endParts = entry.endTime.split(':');
      if (endParts.length == 2) {
        final endMin = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
        if (currentMinutes < endMin) {
          isOngoing = true;
        }
      }
    }

    // Check: does this shift start today and is currently ongoing?
    if (!isOngoing &&
        entry.daysOfWeek.contains(currentWeekday) &&
        !entry.isMutedOnDate(now)) {
      final startParts = entry.startTime.split(':');
      final endParts = entry.endTime.split(':');
      if (startParts.length == 2 && endParts.length == 2) {
        final startMin = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
        int endMin = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
        if (endMin < startMin) endMin += 24 * 60; // Overnight

        isOngoing = (currentMinutes >= startMin && currentMinutes < endMin);
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOngoing
              ? const Color(0xFF10B981).withValues(alpha: 0.6)
              : (isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
          width: isOngoing ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isOngoing
                ? const Color(0xFF10B981).withValues(alpha: isDark ? 0.18 : 0.08)
                : Colors.black.withValues(alpha: isDark ? 0.2 : 0.025),
            blurRadius: isOngoing ? 12 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Subject Icon Box
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: palette.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: palette.border, width: 1.2),
                  ),
                  child: Icon(
                    subjectIcon,
                    color: palette.primary,
                    size: 24,
                  ),
                ),

                const SizedBox(width: 10),

                // Connected Color Dot
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isOngoing ? const Color(0xFF10B981) : palette.primary,
                    shape: BoxShape.circle,
                  ),
                ),

                const SizedBox(width: 10),

                // Subject Title, Time, and Location
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (isMutedNext) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.event_busy_rounded, size: 10, color: Color(0xFFD97706)),
                                  SizedBox(width: 3),
                                  Text(
                                    'Skipped Next',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFD97706),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (isOngoing) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.circle, size: 5.5, color: Color(0xFF10B981)),
                                  SizedBox(width: 3.5),
                                  Text(
                                    'Live',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${TimeUtils.formatTo12Hour(entry.startTime)} – ${TimeUtils.formatTo12Hour(entry.endTime)}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                        ),
                      ),
                      if (entry.location != null && entry.location!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 13, color: palette.primary),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                entry.location!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Trailing Chevron Arrow
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
