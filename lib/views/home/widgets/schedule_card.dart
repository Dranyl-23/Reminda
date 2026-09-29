import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/time_utils.dart';
import '../../../core/utils/schedule_ui_helpers.dart';
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = TimetableTheme.forTitle(entry.title, isDark);
    final subjectIcon = ScheduleUIHelpers.getIconForSubject(entry.title, entry.category);

    final bool isMutedNext = entry.isNextOccurrenceMuted;
    final bool isOngoing = entry.isCurrentlyOngoing();

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
        child: Semantics(
          button: true,
          label: 'View details for ${entry.title}',
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
                Semantics(
                  label: isOngoing ? 'Status: Currently ongoing' : 'Upcoming',
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isOngoing ? const Color(0xFF10B981) : palette.primary,
                      shape: BoxShape.circle,
                    ),
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
    ),
  );
}
}
