import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/page_transitions.dart';
import '../../core/utils/time_utils.dart';
import '../../models/schedule_category.dart';
import '../../models/schedule_entry.dart';
import '../../models/schedule_profile.dart';
import '../../providers/profile_provider.dart';
import '../../providers/schedule_provider.dart';
import '../home/schedule_detail_view.dart';
import '../schedule/add_edit_schedule_view.dart';

class ProfileScheduleTimetableView extends ConsumerStatefulWidget {
  final ScheduleProfile profile;

  const ProfileScheduleTimetableView({
    super.key,
    required this.profile,
  });

  @override
  ConsumerState<ProfileScheduleTimetableView> createState() =>
      _ProfileScheduleTimetableViewState();
}

class _ProfileScheduleTimetableViewState
    extends ConsumerState<ProfileScheduleTimetableView> {
  final GlobalKey _exportBoundaryKey = GlobalKey();
  final TextEditingController _searchController = TextEditingController();
  int? _selectedWeekday; // null = all days, 1 = Mon ... 7 = Sun
  String _viewMode = 'agenda'; // 'agenda', 'week', 'month', 'list'
  bool _weekStartsMonday = true;
  bool _isExporting = false;
  final Set<int> _collapsedDays = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _exportAsImage(List<ScheduleEntry> profileSchedules) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Generating schedule image...',
                  style: TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 300));

      final boundary = _exportBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;

      if (boundary == null) {
        throw Exception('Export canvas not ready.');
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Could not encode PNG image.');
      }

      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final cleanName = widget.profile.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final filePath = '${tempDir.path}/Reminda_${cleanName}_Timetable.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      if (!mounted) return;

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: 'My ${widget.profile.name} Timetable via Reminda',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export image: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allSchedules = ref.watch(scheduleListProvider);
    final profiles = ref.watch(profileListProvider);
    final validProfileIds = profiles.map((p) => p.id).toSet();
    final isTargetActiveOrOnly = widget.profile.isActive || profiles.length <= 1;

    // Filter schedules for this profile (includes unassigned and orphaned-profileId schedules on the active profile)
    final profileSchedules = allSchedules.where((s) {
      if (s.profileId == widget.profile.id) return true;
      final pid = s.profileId?.trim() ?? '';
      final isOrphanedOrUnassigned = pid.isEmpty || !validProfileIds.contains(pid);
      return isTargetActiveOrOnly && isOrphanedOrUnassigned;
    }).toList();

    // Search Filter
    final query = _searchController.text.trim().toLowerCase();
    final filteredSchedules = profileSchedules.where((s) {
      if (query.isEmpty) return true;
      final matchTitle = s.title.toLowerCase().contains(query);
      final matchLocation = s.location?.toLowerCase().contains(query) ?? false;
      final matchNotes = s.notes?.toLowerCase().contains(query) ?? false;
      return matchTitle || matchLocation || matchNotes;
    }).toList();

    // Count statistics
    final totalCourses = filteredSchedules.length;
    int totalMeetings = 0;
    for (final s in filteredSchedules) {
      totalMeetings += s.daysOfWeek.length;
    }

    // Days representation
    final daysList = _weekStartsMonday
        ? [1, 2, 3, 4, 5, 6, 7]
        : [7, 1, 2, 3, 4, 5, 6];

    final currentWeekday = DateTime.now().weekday;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.profile.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              '$totalCourses courses, $totalMeetings meetings',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppColors.borderDark : const Color(0xFFCBD5E1),
                  width: 1.2,
                ),
              ),
              child: const Icon(Icons.grid_view_rounded, size: 18),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: isDark ? AppColors.surfaceDark : Colors.white,
            onSelected: (val) {
              if (val == 'export_image') {
                _exportAsImage(profileSchedules);
              } else if (val == 'toggle_start_day') {
                setState(() => _weekStartsMonday = !_weekStartsMonday);
              } else {
                setState(() => _viewMode = val);
              }
            },
            itemBuilder: (ctx) => [
              _buildPopupOption('agenda', 'Agenda', _viewMode == 'agenda'),
              _buildPopupOption('week', 'Week', _viewMode == 'week'),
              _buildPopupOption('month', 'Month', _viewMode == 'month'),
              _buildPopupOption('list', 'List', _viewMode == 'list'),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'toggle_start_day',
                child: Row(
                  children: [
                    Icon(
                      _weekStartsMonday ? Icons.check_rounded : Icons.calendar_today_rounded,
                      size: 18,
                      color: const Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _weekStartsMonday ? 'Week starts Monday' : 'Week starts Sunday',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'export_image',
                child: Row(
                  children: [
                    Icon(
                      Icons.image_outlined,
                      size: 18,
                      color: Color(0xFF10B981),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Export as Image',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            SmoothSlideFadeRoute(
              page: AddEditScheduleView(
                initialEntry: ScheduleEntry(
                  profileId: widget.profile.id,
                  title: '',
                  daysOfWeek: [_selectedWeekday ?? currentWeekday],
                  startTime: '08:00',
                  endTime: '09:30',
                ),
              ),
            ),
          );
        },
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 4,
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: Stack(
        children: [
          // Hidden offstage canvas for high-resolution 3x export (unconstrained height)
          Positioned(
            left: -9999,
            top: 0,
            child: UnconstrainedBox(
              alignment: Alignment.topLeft,
              child: RepaintBoundary(
                key: _exportBoundaryKey,
                child: _buildExportCanvas(profileSchedules, daysList),
              ),
            ),
          ),

          // Main View
          Column(
            children: [
              // 1. Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: 'Search classes, rooms, instructors',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.textSecondaryDark : const Color(0xFF94A3B8),
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          // 2. Weekday Horizontal Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: daysList.map((dayNum) {
                final isSelected = _selectedWeekday == dayNum;
                final isToday = dayNum == currentWeekday;
                final shortLetter = _getSingleDayLetter(dayNum);
                final hasClasses = profileSchedules.any((s) => s.daysOfWeek.contains(dayNum));

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_selectedWeekday == dayNum) {
                        _selectedWeekday = null; // Toggle back to all
                      } else {
                        _selectedWeekday = dayNum;
                      }
                    });
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFDBEAFE)
                              : (isDark ? AppColors.surfaceDark : Colors.transparent),
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(color: const Color(0xFF2563EB), width: 1.5)
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            shortLetter,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? const Color(0xFF1D4ED8)
                                  : (isDark ? Colors.white : const Color(0xFF334155)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      // Dot indicator for today or has classes
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isToday
                              ? const Color(0xFF2563EB)
                              : (hasClasses
                                  ? (isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1))
                                  : Colors.transparent),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),
          const Divider(height: 1),

          // 3. Timetable Content (Grouped by Day)
          Expanded(
            child: filteredSchedules.isEmpty
                ? _buildEmptyState(isDark)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    children: _buildGroupedDaySections(
                      filteredSchedules,
                      daysList,
                      currentWeekday,
                      isDark,
                    ),
                  ),
          ),
        ],
      ),
    ],
  ),
);
}

  PopupMenuItem<String> _buildPopupOption(String value, String label, bool isSelected) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (isSelected)
            const Icon(Icons.check_rounded, size: 18, color: Color(0xFF2563EB))
          else
            const SizedBox(width: 18),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              color: isSelected ? const Color(0xFF2563EB) : null,
            ),
          ),
        ],
      ),
    );
  }

  String _getSingleDayLetter(int day) {
    switch (day) {
      case 1:
        return 'M';
      case 2:
        return 'T';
      case 3:
        return 'W';
      case 4:
        return 'T';
      case 5:
        return 'F';
      case 6:
        return 'S';
      case 7:
        return 'S';
      default:
        return '';
    }
  }

  List<Widget> _buildGroupedDaySections(
    List<ScheduleEntry> schedules,
    List<int> orderedDays,
    int currentWeekday,
    bool isDark,
  ) {
    final List<Widget> widgets = [];

    final activeDays = _selectedWeekday != null ? [_selectedWeekday!] : orderedDays;

    for (final dayNum in activeDays) {
      // Find all schedules on this day
      final daySchedules = schedules.where((s) => s.daysOfWeek.contains(dayNum)).toList();
      if (daySchedules.isEmpty) continue;

      // Sort by start time
      daySchedules.sort((a, b) => a.startTime.compareTo(b.startTime));

      final dayName = TimeUtils.getWeekdayFull(dayNum);
      final isToday = dayNum == currentWeekday;
      final isCollapsed = _collapsedDays.contains(dayNum);

      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day Accordion Header
              InkWell(
                onTap: () {
                  setState(() {
                    if (isCollapsed) {
                      _collapsedDays.remove(dayNum);
                    } else {
                      _collapsedDays.add(dayNum);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    children: [
                      Icon(
                        isCollapsed ? Icons.chevron_right_rounded : Icons.expand_more_rounded,
                        color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                        size: 22,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        dayName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      if (isToday) ...[
                        const SizedBox(width: 8),
                        const Text(
                          'Today',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        '${daySchedules.length}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (!isCollapsed) ...[
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: List.generate(daySchedules.length, (idx) {
                      final item = daySchedules[idx];
                      final isLast = idx == daySchedules.length - 1;

                      return Column(
                        children: [
                          _buildScheduleRow(item, isDark),
                          if (!isLast)
                            Divider(
                              height: 1,
                              color: isDark ? AppColors.borderDark : const Color(0xFFF1F5F9),
                              indent: 72,
                            ),
                        ],
                      );
                    }),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (widgets.isEmpty) {
      widgets.add(_buildEmptyState(isDark));
    }

    return widgets;
  }

  Widget _buildScheduleRow(ScheduleEntry item, bool isDark) {
    IconData subjectIcon;
    Color iconColor;

    // Detect subject type from title / category
    final lowerTitle = item.title.toLowerCase();
    if (lowerTitle.contains('lab') || lowerTitle.contains(' 2 l') || lowerTitle.contains('2l')) {
      subjectIcon = Icons.science_rounded;
      iconColor = const Color(0xFF0284C7); // cyan/blue for lab
    } else if (item.category == ScheduleCategory.workShift) {
      subjectIcon = Icons.work_rounded;
      iconColor = const Color(0xFFF59E0B);
    } else if (item.category == ScheduleCategory.duty) {
      subjectIcon = Icons.medical_services_rounded;
      iconColor = const Color(0xFF10B981);
    } else if (lowerTitle.contains('capstone') || lowerTitle.contains('thesis')) {
      subjectIcon = Icons.auto_stories_rounded;
      iconColor = const Color(0xFF8B5CF6);
    } else {
      subjectIcon = Icons.menu_book_rounded;
      iconColor = const Color(0xFF2563EB);
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          SmoothSlideFadeRoute(
            page: ScheduleDetailView(entry: item),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Time Column
            SizedBox(
              width: 68,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    TimeUtils.formatTo12Hour(item.startTime),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    TimeUtils.formatTo12Hour(item.endTime),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Icon Badge
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(subjectIcon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),

            // 3. Subject Title & Room / Teacher Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  if (item.notes != null && item.notes!.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.notes!,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (item.location != null && item.location!.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.location!,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (item.notes != null && item.notes!.contains(':')) ...[
                        Expanded(
                          child: Text(
                            item.notes!.split(':').last.trim(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: Color(0xFF2563EB),
                size: 48,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No Classes or Shifts Found',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No results match your search query.'
                  : 'Tap the + button to add schedules to this profile.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportCanvas(List<ScheduleEntry> schedules, List<int> orderedDays) {
    // Curated accent colors for the vertical bar
    const palette = [
      Color(0xFFE11D48), // Rose / Pink (like ITSAM / ITIAS2L)
      Color(0xFF2563EB), // Blue (like ITSAML / ITTHS2)
      Color(0xFF0D9488), // Teal (like ITPROFELEC6 / IAS2)
      Color(0xFF8B5CF6), // Purple (like ITPROFELEC6L)
      Color(0xFFD97706), // Amber / Orange (like ITPROFELEC5L)
      Color(0xFF0284C7), // Sky Blue
      Color(0xFF10B981), // Emerald Green
      Color(0xFF6366F1), // Indigo
    ];

    Color getAccentColor(String title) {
      final index = title.hashCode.abs() % palette.length;
      return palette[index];
    }

    final activeDays = orderedDays
        .where((d) => schedules.any((s) => s.daysOfWeek.contains(d)))
        .toList();

    List<int> leftDays = [];
    List<int> rightDays = [];

    if (activeDays.length <= 1) {
      leftDays = activeDays;
    } else {
      final mid = (activeDays.length / 2).ceil();
      leftDays = activeDays.sublist(0, mid);
      rightDays = activeDays.sublist(mid);
    }

    Widget buildDayColumn(List<int> days) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: days.map((dayNum) {
          final daySchedules =
              schedules.where((s) => s.daysOfWeek.contains(dayNum)).toList()
                ..sort((a, b) => a.startTime.compareTo(b.startTime));

          final dayName = TimeUtils.getWeekdayFull(dayNum);

          return Container(
            margin: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day Title & Meeting Count
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      dayName,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '${daySchedules.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Course Entries
                ...List.generate(daySchedules.length, (idx) {
                  final item = daySchedules[idx];
                  final isLast = idx == daySchedules.length - 1;
                  final accentColor = getAccentColor(item.title);

                  // Extract room string
                  final roomString = item.location != null &&
                          item.location!.trim().isNotEmpty
                      ? (item.location!.toLowerCase().startsWith('room')
                          ? item.location!
                          : 'Room ${item.location!}')
                      : null;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Time Column (Left)
                            SizedBox(
                              width: 66,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    TimeUtils.formatTo12Hour(item.startTime),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    TimeUtils.formatTo12Hour(item.endTime),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // 2. Vertical Color Accent Bar
                            Container(
                              width: 2.5,
                              height: 48,
                              decoration: BoxDecoration(
                                color: accentColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // 3. Course Details (Right)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  if (item.notes != null &&
                                      item.notes!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      item.notes!,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                        height: 1.25,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  if (roomString != null) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      roomString,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Divider(
                            height: 1,
                            color: Color(0xFFF1F5F9),
                          ),
                        ),
                    ],
                  );
                }),
              ],
            ),
          );
        }).toList(),
      );
    }

    final currentYear = DateTime.now().year;

    return Container(
      width: 700,
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header (Top-Left matching reference)
          Text(
            widget.profile.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '1st Semester, AY $currentYear–${currentYear + 1}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 28),

          // 2. 2-Column Schedule Grid
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: buildDayColumn(leftDays)),
              if (rightDays.isNotEmpty) ...[
                const SizedBox(width: 36),
                Expanded(child: buildDayColumn(rightDays)),
              ],
            ],
          ),

          // 3. Footer Branding
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF2563EB)),
                const SizedBox(width: 5),
                Text(
                  'Created with Reminda - Smart Schedule Assistant',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
