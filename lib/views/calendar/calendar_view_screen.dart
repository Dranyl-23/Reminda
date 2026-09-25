import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/time_utils.dart';
import '../../models/schedule_category.dart';
import '../../models/schedule_entry.dart';
import '../../providers/filter_providers.dart';
import '../../providers/schedule_provider.dart';
import '../home/schedule_detail_view.dart';
import 'widgets/weekly_timetable_grid.dart';

class CalendarViewScreen extends ConsumerStatefulWidget {
  const CalendarViewScreen({super.key});

  @override
  ConsumerState<CalendarViewScreen> createState() => _CalendarViewScreenState();
}

class _CalendarViewScreenState extends ConsumerState<CalendarViewScreen> {
  final GlobalKey _timetableBoundaryKey = GlobalKey();
  bool _isExportingImage = false;
  int _viewModeIndex = 0; // 0 = Weekly Timetable Grid, 1 = Monthly Calendar
  DateTime _activeWeekDate = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  Future<void> _exportTimetableAsImage() async {
    if (_isExportingImage) return;
    if (_viewModeIndex != 0) {
      setState(() => _viewModeIndex = 0);
      await Future.delayed(const Duration(milliseconds: 280));
    }

    setState(() => _isExportingImage = true);
    try {
      final boundary = _timetableBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Timetable view is not ready to capture yet.');
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to encode timetable PNG.');
      }

      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/reminda_timetable_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: '📅 My Weekly Timetable • Created with Reminda',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not export image: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExportingImage = false);
      }
    }
  }

  List<ScheduleEntry> _getEventsForDay(DateTime day, List<ScheduleEntry> allSchedules) {
    final weekday = day.weekday; // 1 = Mon .. 7 = Sun
    return allSchedules.where((e) => e.isActive && e.daysOfWeek.contains(weekday)).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final allSchedules = ref.watch(scheduleListProvider)
        .where((e) => e.isActive)
        .toList();

    final selectedDate = _selectedDay ?? _focusedDay;
    final dayEvents = _getEventsForDay(selectedDate, allSchedules);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable & Calendar'),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _isExportingImage ? null : _exportTimetableAsImage,
            tooltip: 'Export Timetable Image (Wallpaper)',
            icon: _isExportingImage
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wallpaper_rounded, size: 21),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              height: 46,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // Tab 0: Weekly Timetable Grid
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _viewModeIndex = 0),
                      child: AnimatedContainer(
                        height: double.infinity,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOut,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: _viewModeIndex == 0
                              ? const LinearGradient(
                                  colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _viewModeIndex == 0
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.grid_view_rounded,
                              size: 16,
                              color: _viewModeIndex == 0
                                  ? Colors.white
                                  : (isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B)),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Weekly Timetable',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _viewModeIndex == 0 ? FontWeight.w800 : FontWeight.w600,
                                color: _viewModeIndex == 0
                                    ? Colors.white
                                    : (isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Tab 1: Monthly Calendar
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _viewModeIndex = 1),
                      child: AnimatedContainer(
                        height: double.infinity,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOut,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: _viewModeIndex == 1
                              ? const LinearGradient(
                                  colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _viewModeIndex == 1
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_month_rounded,
                              size: 16,
                              color: _viewModeIndex == 1
                                  ? Colors.white
                                  : (isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B)),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Monthly Calendar',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _viewModeIndex == 1 ? FontWeight.w800 : FontWeight.w600,
                                color: _viewModeIndex == 1
                                    ? Colors.white
                                    : (isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _viewModeIndex == 0
          ? RepaintBoundary(
              key: _timetableBoundaryKey,
              child: WeeklyTimetableGrid(
                schedules: allSchedules,
                activeWeekDate: _activeWeekDate,
                onWeekChanged: (newDate) {
                  setState(() {
                    _activeWeekDate = newDate;
                  });
                },
              ),
            )
          : _buildMonthlyCalendarView(isDark, allSchedules, selectedDate, dayEvents),
    );
  }

  Widget _buildMonthlyCalendarView(
    bool isDark,
    List<ScheduleEntry> allSchedules,
    DateTime selectedDate,
    List<ScheduleEntry> dayEvents,
  ) {
    return Column(
      children: [
        // TableCalendar Container
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TableCalendar<ScheduleEntry>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            startingDayOfWeek: StartingDayOfWeek.monday,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: (day) => _getEventsForDay(day, allSchedules),
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.textPrimaryDark : const Color(0xFF0F172A),
              ),
              leftChevronIcon: Icon(
                Icons.chevron_left_rounded,
                color: isDark ? AppColors.textPrimaryDark : const Color(0xFF0F172A),
              ),
              rightChevronIcon: Icon(
                Icons.chevron_right_rounded,
                color: isDark ? AppColors.textPrimaryDark : const Color(0xFF0F172A),
              ),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
              ),
              weekendStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
              ),
            ),
            calendarStyle: CalendarStyle(
              markersMaxCount: 3,
              todayDecoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF2563EB), width: 1.5),
              ),
              todayTextStyle: const TextStyle(
                color: Color(0xFF2563EB),
                fontWeight: FontWeight.w800,
              ),
              selectedDecoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              selectedTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            calendarBuilders: CalendarBuilders(
              // Custom Elegant Markers (Single neat pill or max 3 mini-dots)
              markerBuilder: (context, date, events) {
                if (events.isEmpty) return const SizedBox.shrink();

                final distinctCategories = events.map((e) => e.category).toSet().toList();

                return Positioned(
                  bottom: 5,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: distinctCategories.take(3).map((cat) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cat.color,
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              ref.read(selectedDateProvider.notifier).state = selectedDay;
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
          ),
        ),

        // Date Header Banner
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              Text(
                DateFormat('MMMM d, yyyy').format(selectedDate),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.textPrimaryDark : const Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: dayEvents.isNotEmpty
                      ? const Color(0xFF2563EB).withValues(alpha: 0.12)
                      : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${dayEvents.length} Events',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: dayEvents.isNotEmpty
                        ? const Color(0xFF2563EB)
                        : (isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B)),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Day Events List
        Expanded(
          child: dayEvents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_available_rounded,
                        size: 42,
                        color: isDark ? AppColors.textSecondaryDark : const Color(0xFFCBD5E1),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'No scheduled events for this day',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textSecondaryDark : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: dayEvents.length,
                  itemBuilder: (context, index) {
                    final entry = dayEvents[index];
                    final palette = TimetableTheme.forTitle(entry.title, isDark);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: palette.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: palette.border, width: 1.2),
                          ),
                          child: Icon(
                            entry.category.icon,
                            color: palette.primary,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          entry.title,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              Icon(Icons.access_time_rounded, size: 12, color: palette.primary),
                              const SizedBox(width: 4),
                              Text(
                                '${TimeUtils.formatTo12Hour(entry.startTime)} – ${TimeUtils.formatTo12Hour(entry.endTime)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                                ),
                              ),
                              if (entry.location != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: palette.badgeBg,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    entry.location!,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: palette.badgeText,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ScheduleDetailView(entry: entry),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
