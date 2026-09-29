import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/schedule_ui_helpers.dart';
import '../../../core/utils/time_utils.dart';
import '../../../providers/filter_providers.dart';
import '../../../providers/user_setup_provider.dart';
import '../schedule_detail_view.dart';

class UpcomingBanner extends ConsumerWidget {
  const UpcomingBanner({super.key});

  /// Calculates real-time countdown string and progress percentage
  static Map<String, dynamic> computeCountdown(
    String startTimeStr,
    String endTimeStr,
    bool isOngoing,
  ) {
    try {
      final now = DateTime.now();
      final startParts = startTimeStr.split(':');
      final endParts = endTimeStr.split(':');

      final startHour = int.parse(startParts[0]);
      final startMinute = int.parse(startParts[1]);
      final endHour = int.parse(endParts[0]);
      final endMinute = int.parse(endParts[1]);

      var startDateTime = DateTime(now.year, now.month, now.day, startHour, startMinute);
      var endDateTime = DateTime(now.year, now.month, now.day, endHour, endMinute);

      // Handle overnight shift — end is on the next calendar day
      if (endDateTime.isBefore(startDateTime)) {
        endDateTime = endDateTime.add(const Duration(days: 1));
      }

      // BUG FIX (High #14): For post-midnight ongoing shifts, startDateTime
      // was built using today's date, placing it in the future (e.g. 10 PM today
      // when it's currently 2 AM). This caused elapsed/progress to go negative.
      // If isOngoing is true but startDateTime is in the future, the shift
      // actually started yesterday — shift both reference points back one day.
      if (isOngoing && startDateTime.isAfter(now)) {
        startDateTime = startDateTime.subtract(const Duration(days: 1));
        endDateTime = endDateTime.subtract(const Duration(days: 1));
      }

      if (isOngoing) {
        // Class is currently ongoing -> Countdown to END TIME
        final diffToEnd = endDateTime.difference(now);
        final totalDuration = endDateTime.difference(startDateTime);
        final elapsed = now.difference(startDateTime);

        final progress = totalDuration.inSeconds > 0
            ? (elapsed.inSeconds / totalDuration.inSeconds).clamp(0.0, 1.0)
            : 0.0;

        if (diffToEnd.isNegative) {
          return {
            'text': 'Finishing up...',
            'progress': 1.0,
            'isOngoing': true,
          };
        }

        final hours = diffToEnd.inHours;
        final minutes = diffToEnd.inMinutes % 60;
        final seconds = diffToEnd.inSeconds % 60;

        String formatted;
        if (hours > 0) {
          formatted = '${hours}h ${minutes}m ${seconds}s left';
        } else if (minutes > 0) {
          formatted = '${minutes}m ${seconds}s left';
        } else {
          formatted = '${seconds}s left';
        }

        return {
          'text': formatted,
          'progress': progress,
          'isOngoing': true,
        };
      } else {
        // Class is upcoming -> Countdown to START TIME
        final diffToStart = startDateTime.difference(now);

        if (diffToStart.isNegative) {
          return {
            'text': 'Starting now',
            'progress': 0.0,
            'isOngoing': false,
          };
        }

        final hours = diffToStart.inHours;
        final minutes = diffToStart.inMinutes % 60;
        final seconds = diffToStart.inSeconds % 60;

        String formatted;
        if (hours > 0) {
          formatted = 'Starts in ${hours}h ${minutes}m ${seconds}s';
        } else if (minutes > 0) {
          formatted = 'Starts in ${minutes}m ${seconds}s';
        } else {
          formatted = 'Starts in ${seconds}s';
        }

        return {
          'text': formatted,
          'progress': 0.0,
          'isOngoing': false,
        };
      }
    } catch (_) {
      return {
        'text': isOngoing ? 'In progress' : 'Upcoming',
        'progress': 0.0,
        'isOngoing': isOngoing,
      };
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveStatus = ref.watch(activeOrUpcomingScheduleProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (liveStatus == null) {
      final nextUpcoming = ref.watch(nextUpcomingAcrossAllDaysProvider);

      if (nextUpcoming != null) {
        final entry = nextUpcoming.entry;
        final targetDate = nextUpcoming.targetDateTime;

        final subjectIcon = ScheduleUIHelpers.getIconForSubject(entry.title, entry.category);
        final dayLabel = nextUpcoming.isToday
            ? 'Today'
            : (nextUpcoming.daysDifference == 1
                ? 'Tomorrow'
                : DateFormat('EEE, MMM d').format(targetDate));

        final userSetup = ref.watch(userSetupProvider);
        String tagPrefix;
        IconData tagIcon;

        switch (userSetup.role.toLowerCase()) {
          case 'duty':
          case 'medic':
          case 'nurs':
            tagPrefix = 'Next Duty';
            tagIcon = Icons.medical_services_rounded;
            break;
          case 'work':
          case 'job':
          case 'part':
            tagPrefix = 'Next Shift';
            tagIcon = Icons.work_rounded;
            break;
          case 'personal':
          case 'custom':
            tagPrefix = 'Next Routine';
            tagIcon = Icons.schedule_rounded;
            break;
          default:
            tagPrefix = 'Next Class';
            tagIcon = Icons.school_rounded;
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF1E3A8A), // Deep Navy
                Color(0xFF2563EB), // Royal Blue
                Color(0xFF3B82F6), // Vibrant Blue
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Semantics(
              button: true,
              label: 'View schedule details for ${entry.title}',
              child: InkWell(
                onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ScheduleDetailView(entry: entry)),
                );
              },
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row: Category + Day Tag & Countdown (Overflow-guarded)
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  tagIcon,
                                  size: 13,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    '$tagPrefix • $dayLabel',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _NextUpcomingCountdownTicker(targetDate: targetDate),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Subject Title & Icon
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: Icon(subjectIcon, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${TimeUtils.formatTo12Hour(entry.startTime)} – ${TimeUtils.formatTo12Hour(entry.endTime)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.88),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    if ((entry.location != null && entry.location!.isNotEmpty) ||
                        (entry.notes != null && entry.notes!.isNotEmpty)) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            if (entry.location != null && entry.location!.isNotEmpty) ...[
                              const Icon(Icons.meeting_room_outlined, size: 14, color: Colors.white70),
                              const SizedBox(width: 4),
                              Text(
                                entry.location!,
                                style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 12),
                            ],
                            if (entry.notes != null && entry.notes!.isNotEmpty) ...[
                              const Icon(Icons.notes_rounded, size: 14, color: Colors.white70),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  entry.notes!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF10B981),
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All caught up today!',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'No remaining scheduled events or shifts for today.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final entry = liveStatus.entry;
    final isOngoing = liveStatus.isOngoing;
    final subjectIcon = ScheduleUIHelpers.getIconForSubject(entry.title, entry.category);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOngoing
              ? [
                  const Color(0xFF065F46), // Deep Emerald Green for Active
                  const Color(0xFF059669),
                  const Color(0xFF10B981),
                ]
              : [
                  const Color(0xFF0F3BB8), // Deep Royal Blue for Upcoming
                  const Color(0xFF1D4ED8),
                  const Color(0xFF2563EB),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: isOngoing
                ? const Color(0xFF059669).withValues(alpha: 0.35)
                : const Color(0xFF1D4ED8).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Semantics(
          button: true,
          label: 'View schedule details for ${entry.title}',
          child: InkWell(
            onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ScheduleDetailView(entry: entry),
              ),
            );
          },
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row: Status Tag + Live Countdown Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        children: [
                          if (isOngoing) ...[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF34D399),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(
                              isOngoing ? 'HAPPENING NOW' : 'NEXT SCHEDULE',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ActiveCountdownTicker(
                      startTime: entry.startTime,
                      endTime: entry.endTime,
                      isOngoing: isOngoing,
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Content Row: Icon Box + Subject Title & Location
                Row(
                  children: [
                    // Frosted White/Color Icon Box
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                      ),
                      child: Icon(
                        subjectIcon,
                        size: 28,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(width: 14),

                    // Details Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                size: 14,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${TimeUtils.formatTo12Hour(entry.startTime)} – ${TimeUtils.formatTo12Hour(entry.endTime)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          if (entry.location != null &&
                              entry.location!.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 14,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    entry.location!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                // In-Progress Animated Duration Progress Bar
                if (isOngoing) ...[
                  const SizedBox(height: 14),
                  _ProgressBarTicker(
                    startTime: entry.startTime,
                    endTime: entry.endTime,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}

// ---------------------------------------------------------------------------
// Isolated ticker widgets — only these rebuild every second, not the banner.
// ---------------------------------------------------------------------------

/// Ticks every second to display a countdown to a future [targetDate].
/// Used for the "next upcoming across all days" banner variant.
class _NextUpcomingCountdownTicker extends StatefulWidget {
  final DateTime targetDate;
  const _NextUpcomingCountdownTicker({required this.targetDate});

  @override
  State<_NextUpcomingCountdownTicker> createState() =>
      _NextUpcomingCountdownTickerState();
}

class _NextUpcomingCountdownTickerState
    extends State<_NextUpcomingCountdownTicker> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final diff = widget.targetDate.difference(DateTime.now());

    String countdownText;
    if (diff.isNegative) {
      countdownText = 'Starting now';
    } else {
      final days = diff.inDays;
      final hours = diff.inHours % 24;
      final minutes = diff.inMinutes % 60;
      final seconds = diff.inSeconds % 60;

      if (days > 0) {
        countdownText = 'Starts in ${days}d ${hours}h';
      } else if (hours > 0) {
        countdownText = 'Starts in ${hours}h ${minutes}m ${seconds}s';
      } else if (minutes > 0) {
        countdownText = 'Starts in ${minutes}m ${seconds}s';
      } else {
        countdownText = 'Starts in ${seconds}s';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.timer_outlined,
            size: 12.5,
            color: Color(0xFF93C5FD),
          ),
          const SizedBox(width: 4),
          Text(
            countdownText,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ticks every second to show the countdown pill for active/ongoing schedules.
class _ActiveCountdownTicker extends StatefulWidget {
  final String startTime;
  final String endTime;
  final bool isOngoing;

  const _ActiveCountdownTicker({
    required this.startTime,
    required this.endTime,
    required this.isOngoing,
  });

  @override
  State<_ActiveCountdownTicker> createState() => _ActiveCountdownTickerState();
}

class _ActiveCountdownTickerState extends State<_ActiveCountdownTicker> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = UpcomingBanner.computeCountdown(
      widget.startTime,
      widget.endTime,
      widget.isOngoing,
    );
    final countdownText = data['text'] as String;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.isOngoing
                ? Icons.timer_outlined
                : Icons.hourglass_top_rounded,
            size: 13,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            countdownText,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ticks every second to update the progress bar for ongoing schedules.
class _ProgressBarTicker extends StatefulWidget {
  final String startTime;
  final String endTime;

  const _ProgressBarTicker({
    required this.startTime,
    required this.endTime,
  });

  @override
  State<_ProgressBarTicker> createState() => _ProgressBarTickerState();
}

class _ProgressBarTickerState extends State<_ProgressBarTicker> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = UpcomingBanner.computeCountdown(
      widget.startTime,
      widget.endTime,
      true, // always ongoing when this widget is shown
    );
    final progress = data['progress'] as double;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            backgroundColor: Colors.white.withValues(alpha: 0.25),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${(progress * 100).toInt()}% completed',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Colors.white70,
              ),
            ),
            Text(
              'Ends at ${TimeUtils.formatTo12Hour(widget.endTime)}',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

