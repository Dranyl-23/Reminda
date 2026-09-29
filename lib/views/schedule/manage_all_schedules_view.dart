import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/time_utils.dart';
import '../../models/schedule_category.dart';
import '../../providers/schedule_provider.dart';
import '../calendar/widgets/weekly_timetable_grid.dart';
import 'add_edit_schedule_view.dart';

class ManageAllSchedulesView extends ConsumerStatefulWidget {
  const ManageAllSchedulesView({super.key});

  @override
  ConsumerState<ManageAllSchedulesView> createState() => _ManageAllSchedulesViewState();
}

class _ManageAllSchedulesViewState extends ConsumerState<ManageAllSchedulesView> {
  String _searchQuery = '';
  ScheduleCategory? _filterCategory;

  Future<void> _cleanUpDuplicates() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.auto_fix_high_rounded, color: Color(0xFF2563EB), size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Clean Up Duplicates',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Text(
          'This will analyze your schedules for duplicate or redundant entries occupying the same time slots. It keeps the most detailed entry and removes redundant copies from both local storage and cloud sync.\n\nProceed?',
          style: TextStyle(
            fontSize: 13.5,
            color: isDark ? AppColors.textSecondaryDark : const Color(0xFF475569),
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.cleaning_services_rounded, size: 18),
            label: const Text('Clean Up'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final removedCount = await ref.read(scheduleListProvider.notifier).deduplicateSchedules();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          removedCount > 0
              ? 'Removed $removedCount duplicate schedule${removedCount == 1 ? '' : 's'} successfully!'
              : 'No duplicate schedules found. Your timetable is clean!',
        ),
        backgroundColor: removedCount > 0 ? const Color(0xFF16A34A) : const Color(0xFF64748B),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final allSchedules = ref.watch(scheduleListProvider);

    final filtered = allSchedules.where((entry) {
      final matchesSearch = _searchQuery.isEmpty ||
          entry.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (entry.location?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      final matchesCategory = _filterCategory == null || entry.category == _filterCategory;
      return matchesSearch && matchesCategory;
    }).toList()
      ..sort((a, b) => a.title.compareTo(b.title));

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'My Schedules',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_fix_high_rounded, size: 22),
            tooltip: 'Clean Up Duplicates',
            onPressed: _cleanUpDuplicates,
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Color(0xFF2563EB), size: 26),
            tooltip: 'Add Schedule',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddEditScheduleView()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Column(
          children: [
            // Search & Category Filters
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                children: [
                  // Search Bar
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search subjects, rooms, shifts...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      filled: true,
                      fillColor: isDark ? AppColors.surfaceDark : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Category Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All (${allSchedules.length})', null, isDark),
                        ...ScheduleCategory.values.map((cat) {
                          final count = allSchedules.where((e) => e.category == cat).length;
                          return _buildFilterChip('${cat.shortLabel} ($count)', cat, isDark);
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Schedules List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_busy_rounded,
                            size: 48,
                            color: isDark ? AppColors.textSecondaryDark : const Color(0xFFCBD5E1),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No schedules matching "$_searchQuery"'
                                : 'No schedules found',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final entry = filtered[index];
                        final palette = TimetableTheme.forTitle(entry.title, isDark);
                        final daysText = entry.daysOfWeek.map((d) => TimeUtils.getWeekdayShort(d)).join(', ');

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
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
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: palette.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: palette.border, width: 1.2),
                              ),
                              child: Icon(entry.category.icon, color: palette.primary, size: 22),
                            ),
                            title: Text(
                              entry.title,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today_rounded, size: 12, color: palette.primary),
                                      const SizedBox(width: 4),
                                      Text(
                                        daysText,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: palette.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.access_time_rounded, size: 12, color: const Color(0xFF64748B)),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${TimeUtils.formatTo12Hour(entry.startTime)} – ${TimeUtils.formatTo12Hour(entry.endTime)}',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (entry.location != null && entry.location!.trim().isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: palette.badgeBg,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            entry.location!.trim(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: palette.badgeText,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            trailing: Switch.adaptive(
                              value: entry.isActive,
                              // ignore: deprecated_member_use
                              activeColor: const Color(0xFF2563EB),
                              onChanged: (val) {
                                ref.read(scheduleListProvider.notifier).updateSchedule(
                                      entry.copyWith(isActive: val),
                                    );
                              },
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddEditScheduleView(initialEntry: entry),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
  ),
);
  }

  Widget _buildFilterChip(String label, ScheduleCategory? category, bool isDark) {
    final isSelected = _filterCategory == category;

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _filterCategory = selected ? category : null;
          });
        },
        selectedColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? const Color(0xFF2563EB) : (isDark ? Colors.white70 : const Color(0xFF475569)),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isSelected ? const Color(0xFF2563EB) : (isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
          ),
        ),
      ),
    );
  }
}
