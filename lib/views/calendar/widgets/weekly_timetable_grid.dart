import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/time_utils.dart';
import '../../../models/schedule_entry.dart';
import '../../home/schedule_detail_view.dart';

class TimetableTheme {
  final Color primary;
  final Color background;
  final Color border;
  final Color textColor;
  final Color badgeBg;
  final Color badgeText;

  const TimetableTheme({
    required this.primary,
    required this.background,
    required this.border,
    required this.textColor,
    required this.badgeBg,
    required this.badgeText,
  });

  static const List<TimetableTheme> palettes = [
    TimetableTheme(
      primary: Color(0xFF2563EB),
      background: Color(0xFFEFF6FF),
      border: Color(0xFFBFDBFE),
      textColor: Color(0xFF1E3A8A),
      badgeBg: Color(0xFFDBEAFE),
      badgeText: Color(0xFF1D4ED8),
    ),
    TimetableTheme(
      primary: Color(0xFF7C3AED),
      background: Color(0xFFF5F3FF),
      border: Color(0xFFDDD6FE),
      textColor: Color(0xFF4C1D95),
      badgeBg: Color(0xFFEDE9FE),
      badgeText: Color(0xFF6D28D9),
    ),
    TimetableTheme(
      primary: Color(0xFF059669),
      background: Color(0xFFECFDF5),
      border: Color(0xFFA7F3D0),
      textColor: Color(0xFF064E3B),
      badgeBg: Color(0xFFD1FAE5),
      badgeText: Color(0xFF047857),
    ),
    TimetableTheme(
      primary: Color(0xFFD97706),
      background: Color(0xFFFFFBEB),
      border: Color(0xFFFDE68A),
      textColor: Color(0xFF78350F),
      badgeBg: Color(0xFFFEF3C7),
      badgeText: Color(0xFFB45309),
    ),
    TimetableTheme(
      primary: Color(0xFFE11D48),
      background: Color(0xFFFFF1F2),
      border: Color(0xFFFECDD3),
      textColor: Color(0xFF881337),
      badgeBg: Color(0xFFFFE4E6),
      badgeText: Color(0xFFBE123C),
    ),
    TimetableTheme(
      primary: Color(0xFF0891B2),
      background: Color(0xFFECFEFF),
      border: Color(0xFFA5F3FC),
      textColor: Color(0xFF164E63),
      badgeBg: Color(0xFFCFFAFE),
      badgeText: Color(0xFF0E7490),
    ),
    TimetableTheme(
      primary: Color(0xFF4F46E5),
      background: Color(0xFFEEF2FF),
      border: Color(0xFFC7D2FE),
      textColor: Color(0xFF312E81),
      badgeBg: Color(0xFFE0E7FF),
      badgeText: Color(0xFF4338CA),
    ),
  ];

  static TimetableTheme forTitle(String title, bool isDark) {
    final index = title.hashCode.abs() % palettes.length;
    final base = palettes[index];
    if (!isDark) return base;

    // Solid opaque card background in dark mode: rich primary tint blended into dark surface.
    // 100% opaque so background grid lines and any overlapping elements never show through.
    final darkCardBg = Color.alphaBlend(
      base.primary.withValues(alpha: 0.35),
      const Color(0xFF161B2E),
    );

    return TimetableTheme(
      primary: base.primary,
      background: darkCardBg,
      border: base.primary.withValues(alpha: 0.65),
      textColor: Colors.white,
      badgeBg: base.primary.withValues(alpha: 0.45),
      badgeText: Colors.white,
    );
  }
}

class WeeklyTimetableGrid extends StatefulWidget {
  final List<ScheduleEntry> schedules;
  final DateTime activeWeekDate;
  final Function(DateTime) onWeekChanged;

  const WeeklyTimetableGrid({
    super.key,
    required this.schedules,
    required this.activeWeekDate,
    required this.onWeekChanged,
  });

  @override
  State<WeeklyTimetableGrid> createState() => _WeeklyTimetableGridState();
}

class _TimetableLayoutEntry {
  final ScheduleEntry entry;
  final bool isSpillover;
  final int startMinutes;
  final int endMinutes;
  final int durationMinutes;
  final double top;
  final double height;

  const _TimetableLayoutEntry({
    required this.entry,
    required this.isSpillover,
    required this.startMinutes,
    required this.endMinutes,
    required this.durationMinutes,
    required this.top,
    required this.height,
  });
}

class _WeeklyTimetableGridState extends State<WeeklyTimetableGrid> {
  static const double _hourHeight = 65.0;
  static const double _minDayWidth = 125.0;
  static const double _timeColWidth = 52.0;
  static const int _startHour = 6;  // 6:00 AM
  static const int _endHour = 22;   // 10:00 PM

  late ScrollController _verticalController;
  late ScrollController _headerHorizontalController;
  late ScrollController _bodyHorizontalController;
  bool _isSyncingHeader = false;
  bool _isSyncingBody = false;
  bool _showWeekends = true;

  @override
  void initState() {
    super.initState();
    _verticalController = ScrollController();
    _headerHorizontalController = ScrollController();
    _bodyHorizontalController = ScrollController();

    // Link horizontal scroll controllers
    _headerHorizontalController.addListener(() {
      if (_isSyncingBody) return;
      _isSyncingHeader = true;
      if (_bodyHorizontalController.hasClients &&
          _bodyHorizontalController.offset != _headerHorizontalController.offset) {
        _bodyHorizontalController.jumpTo(_headerHorizontalController.offset);
      }
      _isSyncingHeader = false;
    });

    _bodyHorizontalController.addListener(() {
      if (_isSyncingHeader) return;
      _isSyncingBody = true;
      if (_headerHorizontalController.hasClients &&
          _headerHorizontalController.offset != _bodyHorizontalController.offset) {
        _headerHorizontalController.jumpTo(_bodyHorizontalController.offset);
      }
      _isSyncingBody = false;
    });

    // Auto-scroll on initial load to today or 7 AM
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final now = DateTime.now();
      final currentHour = now.hour;
      final targetHour = (currentHour >= _startHour && currentHour <= _endHour)
          ? currentHour
          : 7;
      final scrollOffset = (targetHour - _startHour) * _hourHeight - 20;
      if (_verticalController.hasClients && scrollOffset > 0) {
        _verticalController.animateTo(
          scrollOffset,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }

      final todayWeekday = now.weekday; // 1 = Mon .. 7 = Sun
      if (todayWeekday > 3 && _bodyHorizontalController.hasClients) {
        _bodyHorizontalController.animateTo(
          (todayWeekday - 1) * _minDayWidth - 30,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _headerHorizontalController.dispose();
    _bodyHorizontalController.dispose();
    super.dispose();
  }

  int _timeToMinutes(String timeStr) {
    try {
      final parts = timeStr.split(':');
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    } catch (_) {
      return 0;
    }
  }

  List<DateTime> _getWeekDates(DateTime anchor) {
    final monday = anchor.subtract(Duration(days: anchor.weekday - 1));
    return List.generate(7, (index) => monday.add(Duration(days: index)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final now = DateTime.now();
    final weekDates = _getWeekDates(widget.activeWeekDate);
    final displayedDays = _showWeekends ? weekDates : weekDates.sublist(0, 5);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final dayCount = displayedDays.length;
        final double dayWidth = ((availableWidth - _timeColWidth) / dayCount > _minDayWidth)
            ? (availableWidth - _timeColWidth) / dayCount
            : _minDayWidth;

        return Column(
          children: [
        // Top Week Navigator Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () {
                  widget.onWeekChanged(
                    widget.activeWeekDate.subtract(const Duration(days: 7)),
                  );
                },
                tooltip: 'Previous Week',
              ),
              Expanded(
                child: InkWell(
                  onTap: () => widget.onWeekChanged(DateTime.now()),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Column(
                      children: [
                        Text(
                          '${DateFormat('MMM d').format(weekDates.first)} – ${DateFormat('MMM d, yyyy').format(weekDates.last)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 1),
                        const Text(
                          'Tap to jump to Today',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () {
                  widget.onWeekChanged(
                    widget.activeWeekDate.add(const Duration(days: 7)),
                  );
                },
                tooltip: 'Next Week',
              ),
              ActionChip(
                label: Text(
                  _showWeekends ? '7 Days' : 'Mon-Fri',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
                avatar: Icon(
                  _showWeekends ? Icons.calendar_view_week_rounded : Icons.view_week_rounded,
                  size: 16,
                  color: const Color(0xFF2563EB),
                ),
                onPressed: () {
                  setState(() {
                    _showWeekends = !_showWeekends;
                  });
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Synchronized Sticky Header Row (Time Spacer + Days)
        SizedBox(
          height: 58,
          child: Row(
            children: [
              // Corner Icon Spacer
              Container(
                width: _timeColWidth,
                height: 58,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : const Color(0xFFF8FAFC),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                    ),
                    right: BorderSide(
                      color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.schedule_rounded, size: 18, color: Color(0xFF94A3B8)),
                ),
              ),

              // Days Header Scrollable
              Expanded(
                child: SingleChildScrollView(
                  controller: _headerHorizontalController,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: SizedBox(
                    width: displayedDays.length * dayWidth,
                    child: Row(
                      children: displayedDays.map((date) {
                        final isToday = date.year == now.year &&
                            date.month == now.month &&
                            date.day == now.day;
                        final dayName = DateFormat('E').format(date).toUpperCase();
                        final dayNum = date.day.toString();

                        return Container(
                          width: dayWidth,
                          height: 58,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: isToday
                                ? const Color(0xFF2563EB).withValues(alpha: 0.12)
                                : (isDark ? AppColors.surfaceDark : const Color(0xFFF8FAFC)),
                            border: Border(
                              bottom: BorderSide(
                                color: isToday
                                    ? const Color(0xFF2563EB)
                                    : (isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
                                width: isToday ? 2.5 : 1,
                              ),
                              right: BorderSide(
                                color: isDark
                                    ? AppColors.borderDark
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                dayName,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isToday
                                      ? const Color(0xFF2563EB)
                                      : (isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B)),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: isToday ? const Color(0xFF2563EB) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  dayNum,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: isToday
                                        ? Colors.white
                                        : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Unified Vertical Scrollable Body
        Expanded(
          child: SingleChildScrollView(
            controller: _verticalController,
            physics: const ClampingScrollPhysics(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fixed Left Time Column
                SizedBox(
                  width: _timeColWidth,
                  height: (_endHour - _startHour) * _hourHeight,
                  child: Stack(
                    children: List.generate(_endHour - _startHour, (index) {
                      final hour = _startHour + index;
                      final dt = DateTime(2026, 1, 1, hour);
                      final label = DateFormat('h a').format(dt);

                      return Positioned(
                        top: index * _hourHeight,
                        left: 0,
                        right: 0,
                        height: _hourHeight,
                        child: Container(
                          padding: const EdgeInsets.only(top: 2, right: 6),
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(
                                color: isDark
                                    ? AppColors.borderDark
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                          ),
                          child: Text(
                            label,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                // Horizontally Scrollable Matrix Grid Canvas
                Expanded(
                  child: SingleChildScrollView(
                    controller: _bodyHorizontalController,
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    child: SizedBox(
                      width: displayedDays.length * dayWidth,
                      height: (_endHour - _startHour) * _hourHeight,
                      child: Stack(
                        children: [
                          // Background Grid Lines
                          Positioned.fill(
                            child: Row(
                              children: displayedDays.map((date) {
                                final isToday = date.year == now.year &&
                                    date.month == now.month &&
                                    date.day == now.day;

                                return Container(
                                  width: dayWidth,
                                  decoration: BoxDecoration(
                                    color: isToday
                                        ? const Color(0xFF2563EB).withValues(alpha: 0.02)
                                        : Colors.transparent,
                                    border: Border(
                                      right: BorderSide(
                                        color: isDark
                                            ? AppColors.borderDark.withValues(alpha: 0.6)
                                            : const Color(0xFFF1F5F9),
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    children: List.generate(
                                      _endHour - _startHour,
                                      (index) => Container(
                                        height: _hourHeight,
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: isDark
                                                  ? AppColors.borderDark.withValues(alpha: 0.4)
                                                  : const Color(0xFFF1F5F9),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                          // Subject Schedule Event Blocks
                          ..._buildEventBlocks(displayedDays, isDark, dayWidth),

                          // Current Time Indicator Line (for Today)
                          _buildCurrentTimeIndicator(displayedDays, dayWidth),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
      },
    );
  }

  List<Widget> _buildEventBlocks(List<DateTime> displayedDays, bool isDark, double dayWidth) {
    final List<Widget> blocks = [];

    for (int dayIndex = 0; dayIndex < displayedDays.length; dayIndex++) {
      final date = displayedDays[dayIndex];
      final weekday = date.weekday; // 1 = Mon .. 7 = Sun

      final dayEntries = widget.schedules.where(
        (e) => e.isActive && e.daysOfWeek.contains(weekday),
      );

      // Also include overnight entries from the PREVIOUS day that spill into this day
      final prevWeekday = weekday == 1 ? 7 : weekday - 1;
      final overnightSpillover = widget.schedules.where(
        (e) => e.isActive && e.spansNextDay && e.daysOfWeek.contains(prevWeekday),
      );

      // Combine and deduplicate by entry.id to avoid duplicate renders
      final seenIds = <String>{};
      final uniqueDayEntries = <ScheduleEntry>[];
      for (final entry in [...dayEntries, ...overnightSpillover]) {
        if (seenIds.add(entry.id)) {
          uniqueDayEntries.add(entry);
        }
      }

      final layoutEntries = <_TimetableLayoutEntry>[];
      for (final entry in uniqueDayEntries) {
        final startMinutes = _timeToMinutes(entry.startTime);
        final endMinutes = _timeToMinutes(entry.endTime);

        final bool isSpillover = entry.spansNextDay && !entry.daysOfWeek.contains(weekday);
        final effectiveStartMinutes = isSpillover ? 0 : startMinutes;
        final effectiveEndMinutes = isSpillover ? endMinutes : endMinutes;

        final gridStartMinutes = _startHour * 60;
        final startOffsetMinutes = effectiveStartMinutes - gridStartMinutes;
        final durationMinutes = effectiveEndMinutes > effectiveStartMinutes
            ? (effectiveEndMinutes - effectiveStartMinutes)
            : (isSpillover ? effectiveEndMinutes : (24 * 60 - effectiveStartMinutes + effectiveEndMinutes));

        if (startOffsetMinutes + durationMinutes < 0) continue;

        final gridTotalMinutes = (_endHour - _startHour) * 60;
        final cappedDuration = (startOffsetMinutes + durationMinutes > gridTotalMinutes)
            ? (gridTotalMinutes - startOffsetMinutes).clamp(0, gridTotalMinutes)
            : durationMinutes;

        final top = (startOffsetMinutes / 60.0) * _hourHeight;
        final height = (cappedDuration / 60.0) * _hourHeight;

        layoutEntries.add(_TimetableLayoutEntry(
          entry: entry,
          isSpillover: isSpillover,
          startMinutes: effectiveStartMinutes,
          endMinutes: effectiveStartMinutes + durationMinutes,
          durationMinutes: durationMinutes,
          top: top,
          height: height,
        ));
      }

      // Sort entries chronologically: earlier start first, longer duration first
      layoutEntries.sort((a, b) {
        final cmpStart = a.startMinutes.compareTo(b.startMinutes);
        if (cmpStart != 0) return cmpStart;
        final cmpDur = b.durationMinutes.compareTo(a.durationMinutes);
        if (cmpDur != 0) return cmpDur;
        return a.entry.id.compareTo(b.entry.id);
      });

      // Group into clusters of overlapping events
      final clusters = <List<_TimetableLayoutEntry>>[];
      var currentCluster = <_TimetableLayoutEntry>[];
      int clusterEnd = -1;

      for (final item in layoutEntries) {
        if (currentCluster.isEmpty) {
          currentCluster.add(item);
          clusterEnd = item.endMinutes;
        } else if (item.startMinutes < clusterEnd) {
          // Overlaps with the current cluster
          currentCluster.add(item);
          if (item.endMinutes > clusterEnd) {
            clusterEnd = item.endMinutes;
          }
        } else {
          clusters.add(currentCluster);
          currentCluster = [item];
          clusterEnd = item.endMinutes;
        }
      }
      if (currentCluster.isNotEmpty) {
        clusters.add(currentCluster);
      }

      // For each cluster, assign parallel lanes (sub-columns) so overlapping cards sit side-by-side
      for (final cluster in clusters) {
        final laneEndMinutes = <int>[];
        final itemLane = <_TimetableLayoutEntry, int>{};

        for (final item in cluster) {
          int assignedLane = -1;
          for (int laneIdx = 0; laneIdx < laneEndMinutes.length; laneIdx++) {
            if (laneEndMinutes[laneIdx] <= item.startMinutes) {
              assignedLane = laneIdx;
              laneEndMinutes[laneIdx] = item.endMinutes;
              break;
            }
          }
          if (assignedLane == -1) {
            assignedLane = laneEndMinutes.length;
            laneEndMinutes.add(item.endMinutes);
          }
          itemLane[item] = assignedLane;
        }

        final totalLanes = laneEndMinutes.length;
        final colLeft = dayIndex * dayWidth;
        final availableColWidth = dayWidth - 6.0;
        final laneWidth = availableColWidth / totalLanes;

        for (final item in cluster) {
          final lane = itemLane[item]!;
          final blockLeft = colLeft + 3.0 + (lane * laneWidth);
          final blockWidth = (laneWidth - (totalLanes > 1 ? 2.0 : 0.0)).clamp(24.0, dayWidth);
          final blockHeight = (item.height - 3.0).clamp(32.0, 600.0);

          final entry = item.entry;
          final palette = TimetableTheme.forTitle(entry.title, isDark);

          blocks.add(
            Positioned(
              top: item.top + 1,
              left: blockLeft,
              width: blockWidth,
              height: blockHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ScheduleDetailView(entry: entry),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: totalLanes > 1 ? 5 : 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: palette.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: palette.border, width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: palette.primary.withValues(alpha: isDark ? 0.25 : 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.title,
                            maxLines: blockHeight > 55 ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: totalLanes > 1 ? 10.5 : 11.5,
                              fontWeight: FontWeight.w800,
                              color: palette.textColor,
                              letterSpacing: -0.2,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (blockWidth > 68) ...[
                                Icon(Icons.access_time_rounded, size: 10, color: palette.primary),
                                const SizedBox(width: 3),
                              ],
                              Expanded(
                                child: Text(
                                  blockWidth < 75
                                      ? TimeUtils.formatTo12Hour(entry.startTime)
                                      : '${TimeUtils.formatTo12Hour(entry.startTime)} – ${TimeUtils.formatTo12Hour(entry.endTime)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: totalLanes > 1 ? 8.5 : 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: palette.textColor.withValues(alpha: 0.9),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (entry.location != null &&
                              entry.location!.isNotEmpty &&
                              blockHeight > 50) ...[
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: palette.badgeBg,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                entry.location!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: totalLanes > 1 ? 8.0 : 9.0,
                                  fontWeight: FontWeight.w800,
                                  color: palette.badgeText,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      }
    }

    return blocks;
  }

  Widget _buildCurrentTimeIndicator(List<DateTime> displayedDays, double dayWidth) {
    final now = DateTime.now();
    final todayIndex = displayedDays.indexWhere(
      (d) => d.year == now.year && d.month == now.month && d.day == now.day,
    );

    if (todayIndex == -1) return const SizedBox.shrink();

    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = _startHour * 60;
    final endMinutes = _endHour * 60;

    if (currentMinutes < startMinutes || currentMinutes > endMinutes) {
      return const SizedBox.shrink();
    }

    final top = ((currentMinutes - startMinutes) / 60.0) * _hourHeight;
    final left = todayIndex * dayWidth;

    return Positioned(
      top: top - 4,
      left: left,
      width: dayWidth,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFEF4444),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Container(
              height: 2,
              color: const Color(0xFFEF4444),
            ),
          ),
        ],
      ),
    );
  }
}
