import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ai/ai_training_telemetry_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/time_utils.dart';
import '../../models/schedule_category.dart';
import '../../models/schedule_entry.dart';
import '../../providers/profile_provider.dart';
import '../../providers/schedule_provider.dart';
import '../navigation/main_navigation_shell.dart';
import 'edit_scanned_entry_view.dart';

class ReviewScannedSchedulesView extends ConsumerStatefulWidget {
  final List<ScheduleEntry> initialEntries;

  const ReviewScannedSchedulesView({
    super.key,
    required this.initialEntries,
  });

  @override
  ConsumerState<ReviewScannedSchedulesView> createState() =>
      _ReviewScannedSchedulesViewState();
}

class _ReviewScannedSchedulesViewState
    extends ConsumerState<ReviewScannedSchedulesView> {
  late List<ScheduleEntry> _entries;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _entries = List.from(widget.initialEntries);
  }

  void _onAddNewEntry() async {
    final newDraft = ScheduleEntry(
      title: '',
      category: ScheduleCategory.classSchedule,
      daysOfWeek: [DateTime.now().weekday],
      startTime: '08:00',
      endTime: '09:30',
      location: '',
      notes: 'Manually added',
      reminders: [15],
      isActive: true,
    );

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => EditScannedEntryView(entry: newDraft, isNew: true),
      ),
    );

    if (result != null && result['entry'] != null && mounted) {
      setState(() {
        _entries.add(result['entry'] as ScheduleEntry);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Added new schedule!'),
          backgroundColor: Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onEditEntry(int index) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => EditScannedEntryView(entry: _entries[index]),
      ),
    );

    if (result != null && mounted) {
      if (result['deleted'] == true) {
        setState(() {
          _entries.removeAt(index);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event removed from schedule')),
        );
      } else if (result['entry'] != null) {
        setState(() {
          _entries[index] = result['entry'] as ScheduleEntry;
        });
      }
    }
  }

  void _onSaveAll() async {
    if (_isSaving) return;

    if (_entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No schedule entries to save')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final activeProfile = ref.read(activeProfileProvider);
      final entriesToSave = _entries.map((e) {
        if (e.profileId == null && activeProfile != null) {
          return e.copyWith(profileId: activeProfile.id);
        }
        return e;
      }).toList();

      await ref.read(scheduleListProvider.notifier).addBatch(entriesToSave);

      // Asynchronously submit anonymous ground-truth AI telemetry if opted-in
      AiTrainingTelemetryService.recordGroundTruthSample(
        entries: entriesToSave,
        institutionName: activeProfile?.name,
        role: activeProfile?.type,
        source: 'offline_scanner_review',
      );

      if (mounted) {
        // Switch active tab to Timetable & Calendar so user immediately sees saved schedules
        ref.read(navigationIndexProvider.notifier).state = 1;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully saved ${entriesToSave.length} schedules!'),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Review & Edit',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
        actions: [
          TextButton.icon(
            onPressed: _onAddNewEntry,
            icon: const Icon(Icons.add_rounded, size: 18, color: Color(0xFF2563EB)),
            label: const Text(
              'Add',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2563EB),
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _entries.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.event_busy_rounded,
                              size: 48,
                              color: isDark ? AppColors.textSecondaryDark : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No schedule entries found.',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _onAddNewEntry,
                              icon: const Icon(Icons.add_rounded, size: 20),
                              label: const Text('Add Schedule Manually'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _entries.length + 2,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          // Top Summary Banner
                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'We found ${_entries.length} schedules.',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E3A8A),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                const Text(
                                  'Please review and edit before saving.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        // Last item: "+ Add Missing Schedule" Button
                        if (index == _entries.length + 1) {
                          return Container(
                            margin: const EdgeInsets.only(top: 4, bottom: 20),
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _onAddNewEntry,
                              icon: const Icon(Icons.add_circle_outline_rounded, size: 20, color: Color(0xFF2563EB)),
                              label: const Text(
                                'Add Missing Schedule',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(
                                  color: Color(0xFF93C5FD),
                                  width: 1.5,
                                ),
                                backgroundColor: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFEFF6FF),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          );
                        }

                        final entryIndex = index - 1;
                        final ScheduleEntry entry = _entries[entryIndex];
                        final primaryDay = entry.daysOfWeek.isNotEmpty ? entry.daysOfWeek.first : 1;
                        final dayColor = TimeUtils.getDayColor(primaryDay);
                        final dayAbbr = TimeUtils.formatDaysAbbr(entry.daysOfWeek);

                        // Detect conflicts against other scanned entries and existing saved schedules
                        final existingSchedules = ref.watch(scheduleListProvider);
                        final otherScanned = _entries.where((e) => e.id != entry.id).toList();
                        final entryConflicts = TimeUtils.findConflicts(
                          entry,
                          [...otherScanned, ...existingSchedules],
                        );
                        final bool hasConflict = entryConflicts.isNotEmpty;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceDark : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: hasConflict
                                  ? const Color(0xFFF59E0B).withValues(alpha: 0.65)
                                  : (isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
                              width: hasConflict ? 1.4 : 1,
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (hasConflict)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFD97706)),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          'Overlap: ${entryConflicts.first.summaryText}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFFD97706),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                              // Left: Day Badge & Category Icon Column
                              Column(
                                children: [
                                  Text(
                                    dayAbbr,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w900,
                                      color: dayColor,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      entry.category.icon,
                                      color: dayColor,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(width: 14),

                              // Middle: Title, Time, Location
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.title,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF2563EB)),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${TimeUtils.formatTo12Hour(entry.startTime)} – ${TimeUtils.formatTo12Hour(entry.endTime)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (entry.location != null && entry.location!.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF64748B)),
                                          const SizedBox(width: 4),
                                          Text(
                                            entry.location!,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              const SizedBox(width: 8),

                              // Right: Edit Button
                              OutlinedButton(
                                onPressed: () => _onEditEntry(entryIndex),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  side: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  backgroundColor: isDark ? Colors.transparent : Colors.white,
                                ),
                                child: const Text(
                                  'Edit',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                    },
                    ),
            ),

            // Bottom Sticky Save Schedule Button matching mockup
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _onSaveAll,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 20),
                  label: Text(
                    _isSaving ? 'Saving...' : 'Save Schedule (${_entries.length})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
