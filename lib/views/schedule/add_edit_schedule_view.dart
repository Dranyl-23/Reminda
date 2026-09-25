import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/time_utils.dart';
import '../../models/schedule_category.dart';
import '../../models/schedule_entry.dart';
import '../../providers/profile_provider.dart';
import '../../providers/schedule_provider.dart';
import 'widgets/day_selector_chips.dart';
import 'widgets/reminder_picker.dart';

class AddEditScheduleView extends ConsumerStatefulWidget {
  final ScheduleEntry? initialEntry;

  const AddEditScheduleView({
    super.key,
    this.initialEntry,
  });

  @override
  ConsumerState<AddEditScheduleView> createState() => _AddEditScheduleViewState();
}

class _AddEditScheduleViewState extends ConsumerState<AddEditScheduleView> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _notesController;

  late ScheduleCategory _selectedCategory;
  late List<int> _selectedDays;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late bool _spansNextDay;
  late List<int> _reminders;
  bool _isSaving = false;

  bool get _isEditing => widget.initialEntry != null;

  @override
  void initState() {
    super.initState();
    final e = widget.initialEntry;
    _titleController = TextEditingController(text: e?.title ?? '');
    _locationController = TextEditingController(text: e?.location ?? '');
    _notesController = TextEditingController(text: e?.notes ?? '');

    _selectedCategory = e?.category ?? ScheduleCategory.classSchedule;
    _selectedDays = e?.daysOfWeek != null && e!.daysOfWeek.isNotEmpty
        ? List<int>.from(e.daysOfWeek)
        : [DateTime.now().weekday];
    _startTime = e != null ? TimeUtils.stringToTimeOfDay(e.startTime) : const TimeOfDay(hour: 8, minute: 30);
    _endTime = e != null ? TimeUtils.stringToTimeOfDay(e.endTime) : const TimeOfDay(hour: 10, minute: 0);
    _spansNextDay = e?.spansNextDay ?? false;
    _reminders = e?.reminders != null && e!.reminders.isNotEmpty
        ? List<int>.from(e.reminders)
        : [_selectedCategory.defaultReminderLeadMinutes];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
        // Auto-check spans overnight
        final startStr = TimeUtils.timeOfDayToString(_startTime);
        final endStr = TimeUtils.timeOfDayToString(_endTime);
        _spansNextDay = TimeUtils.checkSpansOvernight(startStr, endStr);
      });
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;

    // Fix #7: activate all TextFormField validators via the Form key
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();

    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one day of the week.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    // Fix #9: reject logically impossible time range for non-overnight shifts
    if (!_spansNextDay) {
      final startStr = TimeUtils.timeOfDayToString(_startTime);
      final endStr   = TimeUtils.timeOfDayToString(_endTime);
      final startMins = _startTime.hour * 60 + _startTime.minute;
      final endMins   = _endTime.hour   * 60 + _endTime.minute;
      if (endMins <= startMins) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'End time (${TimeUtils.formatTo12Hour(endStr)}) must be after '
              'start time (${TimeUtils.formatTo12Hour(startStr)}), '
              'or enable "Crosses midnight".',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFDC2626),
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final startStr = TimeUtils.timeOfDayToString(_startTime);
      final endStr = TimeUtils.timeOfDayToString(_endTime);
      final activeProfile = ref.read(activeProfileProvider);

      final entry = ScheduleEntry(
        id: widget.initialEntry?.id,
        profileId: widget.initialEntry?.profileId ?? activeProfile?.id,
        title: title,
        category: _selectedCategory,
        daysOfWeek: _selectedDays,
        startTime: startStr,
        endTime: endStr,
        spansNextDay: _spansNextDay,
        location: _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : null,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        reminders: _reminders,
        isActive: widget.initialEntry?.isActive ?? true,
        mutedDates: widget.initialEntry?.mutedDates,
        createdAt: widget.initialEntry?.createdAt,
        sourceImageId: widget.initialEntry?.sourceImageId,
      );

      final allSchedules = ref.read(scheduleListProvider);
      final conflicts = TimeUtils.findConflicts(entry, allSchedules);
      if (conflicts.isNotEmpty) {
        final saveAnyway = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Schedule Conflict',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This schedule overlaps with existing classes/shifts:',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                ...conflicts.take(3).map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.schedule_rounded, size: 15, color: Color(0xFFD97706)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                c.summaryText,
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                const SizedBox(height: 6),
                const Text(
                  'Do you want to save it anyway?',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Adjust Time', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save Anyway', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        );
        if (saveAnyway != true) {
          setState(() => _isSaving = false);
          return;
        }
      }

      final notifier = ref.read(scheduleListProvider.notifier);
      if (_isEditing) {
        await notifier.updateSchedule(entry);
      } else {
        await notifier.addSchedule(entry);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('AddEditScheduleView: Error saving: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save schedule: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final startStr = TimeUtils.timeOfDayToString(_startTime);
    final endStr = TimeUtils.timeOfDayToString(_endTime);
    final durationText = TimeUtils.calculateDuration(startStr, endStr, spansNextDay: _spansNextDay);
    final activeProfile = ref.watch(activeProfileProvider);
    final allSchedules = ref.watch(scheduleListProvider);
    final liveConflicts = TimeUtils.findConflicts(
      ScheduleEntry(
        id: widget.initialEntry?.id,
        profileId: widget.initialEntry?.profileId ?? activeProfile?.id,
        title: _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : 'Draft',
        category: _selectedCategory,
        daysOfWeek: _selectedDays,
        startTime: startStr,
        endTime: endStr,
        spansNextDay: _spansNextDay,
      ),
      allSchedules,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Schedule' : 'New Schedule'),
        actions: [
          _isSaving
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.only(right: 16.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _save,
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (liveConflicts.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 18),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFD97706)),
                        SizedBox(width: 6),
                        Text(
                          'Time Overlap Detected',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFD97706),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ...liveConflicts.take(2).map(
                          (c) => Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '• ${c.summaryText}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF78350F),
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ],
            // Category Selector
            const Text(
              'CATEGORY',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondaryLight,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ScheduleCategory.values.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(cat.icon, size: 16, color: isSelected ? Colors.white : cat.color),
                          const SizedBox(width: 6),
                          Text(cat.displayName),
                        ],
                      ),
                      selected: isSelected,
                      selectedColor: cat.color,
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : null,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedCategory = cat;
                            if (!_isEditing) {
                              _reminders = [cat.defaultReminderLeadMinutes];
                            }
                          });
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 24),

            // Title
            const Text(
              'SCHEDULE TITLE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondaryLight,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              maxLength: 100,
              decoration: InputDecoration(
                hintText: _selectedCategory == ScheduleCategory.classSchedule
                    ? 'e.g. IT 101 - Programming 1'
                    : (_selectedCategory == ScheduleCategory.workShift
                        ? 'e.g. Cashier Shift - Afternoon'
                        : 'e.g. Hospital ER Duty'),
                prefixIcon: const Icon(Icons.title_rounded, size: 20),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter a schedule title';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),

            // Days of the Week
            const Text(
              'DAYS OF THE WEEK',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondaryLight,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            DaySelectorChips(
              selectedDays: _selectedDays,
              onChanged: (days) {
                setState(() {
                  _selectedDays = days;
                });
              },
            ),

            const SizedBox(height: 24),

            // Time Selection Card
            const Text(
              'TIME & DURATION',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondaryLight,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Start Time
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickTime(isStart: true),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'START TIME',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondaryLight),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  TimeUtils.formatTo12Hour(startStr),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(Icons.arrow_forward_rounded, size: 20, color: AppColors.textSecondaryLight),
                      ),
                      // End Time
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickTime(isStart: false),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'END TIME',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondaryLight),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  TimeUtils.formatTo12Hour(endStr),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Duration display & Spans next day toggle
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Duration: $durationText',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Text(
                            'Crosses midnight',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 4),
                          Checkbox(
                            value: _spansNextDay,
                            onChanged: (val) {
                              setState(() {
                                _spansNextDay = val ?? false;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Location
            const Text(
              'LOCATION / ROOM / STATION (OPTIONAL)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondaryLight,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                hintText: 'e.g. Room 304, Mall Branch 1, ER Ward',
                prefixIcon: Icon(Icons.location_on_outlined, size: 20),
              ),
            ),

            const SizedBox(height: 24),

            // Reminder Lead Times
            const Text(
              'REMINDER ALARMS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondaryLight,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            ReminderPicker(
              selectedLeadMinutes: _reminders,
              onChanged: (updated) {
                setState(() {
                  _reminders = updated;
                });
              },
            ),

            const SizedBox(height: 24),

            // Notes
            const Text(
              'NOTES / PROFESSOR / SUPERVISOR (OPTIONAL)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondaryLight,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g. Bring lab equipment, supervisor contact number...',
              ),
            ),

            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_isEditing ? Icons.check_circle_rounded : Icons.add_circle_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _isEditing ? 'Save Changes' : 'Add to Schedule',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
