import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/time_utils.dart';
import '../../models/schedule_category.dart';
import '../../models/schedule_entry.dart';

class EditScannedEntryView extends StatefulWidget {
  final ScheduleEntry entry;
  final bool isNew;

  const EditScannedEntryView({
    super.key,
    required this.entry,
    this.isNew = false,
  });

  @override
  State<EditScannedEntryView> createState() => _EditScannedEntryViewState();
}

class _EditScannedEntryViewState extends State<EditScannedEntryView> {
  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _inChargeController;
  late TextEditingController _notesController;

  late ScheduleCategory _selectedCategory;
  late List<int> _selectedDays;
  late String _startTime;
  late String _endTime;
  late int _selectedReminderLead;
  late bool _spansNextDay;

  final List<Map<String, dynamic>> _weekdays = [
    {'day': 1, 'name': 'Monday'},
    {'day': 2, 'name': 'Tuesday'},
    {'day': 3, 'name': 'Wednesday'},
    {'day': 4, 'name': 'Thursday'},
    {'day': 5, 'name': 'Friday'},
    {'day': 6, 'name': 'Saturday'},
    {'day': 7, 'name': 'Sunday'},
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.entry.title);
    _locationController = TextEditingController(text: widget.entry.location ?? '');

    // Parse person in charge vs additional notes from existing notes
    final rawNotes = widget.entry.notes ?? '';
    if (rawNotes.startsWith('Prof.') ||
        rawNotes.startsWith('Dr.') ||
        rawNotes.startsWith('Engr.') ||
        rawNotes.startsWith('Supervisor') ||
        rawNotes.startsWith('Manager') ||
        rawNotes.startsWith('Nurse') ||
        !rawNotes.contains('\n')) {
      _inChargeController = TextEditingController(text: rawNotes != 'Scanned via On-Device AI' ? rawNotes : '');
      _notesController = TextEditingController(text: '');
    } else {
      final lines = rawNotes.split('\n');
      _inChargeController = TextEditingController(text: lines.first);
      _notesController = TextEditingController(text: lines.skip(1).join('\n'));
    }

    _selectedCategory = widget.entry.category;
    _selectedDays = List.from(widget.entry.daysOfWeek);
    _startTime = widget.entry.startTime;
    _endTime = widget.entry.endTime;
    _selectedReminderLead = widget.entry.reminders.isNotEmpty ? widget.entry.reminders.first : 15;
    _spansNextDay = widget.entry.spansNextDay || TimeUtils.checkSpansOvernight(_startTime, _endTime);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _inChargeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool isStart}) async {
    final currentStr = isStart ? _startTime : _endTime;
    final parts = currentStr.split(':');
    final initialHour = parts.length == 2 ? int.tryParse(parts[0]) ?? 8 : 8;
    final initialMinute = parts.length == 2 ? int.tryParse(parts[1]) ?? 0 : 0;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
    );

    if (picked != null) {
      final hourStr = picked.hour.toString().padLeft(2, '0');
      final minuteStr = picked.minute.toString().padLeft(2, '0');
      final timeFormatted = '$hourStr:$minuteStr';

      setState(() {
        if (isStart) {
          _startTime = timeFormatted;
        } else {
          _endTime = timeFormatted;
        }
      });
    }
  }

  void _onDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Event', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Are you sure you want to remove "${widget.entry.title}" from this scan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.pop(context, {'deleted': true});
    }
  }

  void _onSave() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an event title')),
      );
      return;
    }

    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one day')),
      );
      return;
    }

    // Fix: check time range against explicit overnight toggle state
    final startParts = _startTime.split(':');
    final endParts   = _endTime.split(':');
    final startMins  = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    final endMins    = int.parse(endParts[0])   * 60 + int.parse(endParts[1]);

    if (!_spansNextDay && endMins <= startMins) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'End time (${TimeUtils.formatTo12Hour(_endTime)}) must be after '
            'start time (${TimeUtils.formatTo12Hour(_startTime)}), '
            'or toggle "Crosses midnight / Overnight shift".',
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    final inCharge = _inChargeController.text.trim();
    final additionalNotes = _notesController.text.trim();

    String? finalNotes;
    if (inCharge.isNotEmpty && additionalNotes.isNotEmpty) {
      finalNotes = '$inCharge\n$additionalNotes';
    } else if (inCharge.isNotEmpty) {
      finalNotes = inCharge;
    } else if (additionalNotes.isNotEmpty) {
      finalNotes = additionalNotes;
    }

    final updatedEntry = widget.entry.copyWith(
      title: title,
      category: _selectedCategory,
      daysOfWeek: _selectedDays,
      startTime: _startTime,
      endTime: _endTime,
      spansNextDay: _spansNextDay || (endMins < startMins),
      location: _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : null,
      notes: finalNotes,
      reminders: [_selectedReminderLead],
    );

    Navigator.pop(context, {'entry': updatedEntry});
  }

  String _getTitleHint() {
    switch (_selectedCategory) {
      case ScheduleCategory.classSchedule:
        return 'e.g. Computer Programming 1';
      case ScheduleCategory.workShift:
        return 'e.g. Cashier Shift, Opening Crew, BPO Agent';
      case ScheduleCategory.duty:
        return 'e.g. ER Duty, Ward Rotation, Clinic Shift';
      case ScheduleCategory.custom:
        return 'e.g. Morning Workout, Department Meeting';
    }
  }

  String _getInChargeLabel() {
    switch (_selectedCategory) {
      case ScheduleCategory.classSchedule:
        return 'Instructor / Professor (optional)';
      case ScheduleCategory.workShift:
        return 'Supervisor / Manager / Lead (optional)';
      case ScheduleCategory.duty:
        return 'Head Nurse / Doctor / Preceptor (optional)';
      case ScheduleCategory.custom:
        return 'Person-in-Charge / Officer / Lead (optional)';
    }
  }

  String _getInChargeHint() {
    switch (_selectedCategory) {
      case ScheduleCategory.classSchedule:
        return 'e.g. Prof. Saragena or Dr. Santos';
      case ScheduleCategory.workShift:
        return 'e.g. Shift Manager, Team Lead, Supervisor';
      case ScheduleCategory.duty:
        return 'e.g. Dr. Reyes, Head Nurse, Charge Nurse';
      case ScheduleCategory.custom:
        return 'e.g. Department Head, Coach, or Officer';
    }
  }

  IconData _getInChargeIcon() {
    switch (_selectedCategory) {
      case ScheduleCategory.classSchedule:
        return Icons.school_outlined;
      case ScheduleCategory.workShift:
        return Icons.badge_outlined;
      case ScheduleCategory.duty:
        return Icons.medical_services_outlined;
      case ScheduleCategory.custom:
        return Icons.person_pin_circle_outlined;
    }
  }

  String _getLocationLabel() {
    switch (_selectedCategory) {
      case ScheduleCategory.classSchedule:
        return 'Location / Room';
      case ScheduleCategory.workShift:
        return 'Workplace / Branch / Station';
      case ScheduleCategory.duty:
        return 'Hospital / Ward / Station';
      case ScheduleCategory.custom:
        return 'Location / Venue / Office';
    }
  }

  String _getLocationHint() {
    switch (_selectedCategory) {
      case ScheduleCategory.classSchedule:
        return 'e.g. CLB 2, Room 304, or Online';
      case ScheduleCategory.workShift:
        return 'e.g. Jollibee Main Branch, Kitchen, Counter 1';
      case ScheduleCategory.duty:
        return 'e.g. Station 3, Ward 4, Emergency Room';
      case ScheduleCategory.custom:
        return 'e.g. Office 201, City Hall, Gym';
    }
  }

  String _getReminderLabel(int minutes) {
    switch (minutes) {
      case 0:
        return 'At time of event';
      case 5:
        return '5 minutes before';
      case 10:
        return '10 minutes before';
      case 15:
        return '15 minutes before';
      case 30:
        return '30 minutes before';
      case 60:
        return '1 hour before';
      default:
        return '$minutes minutes before';
    }
  }

  void _showReminderPicker(bool isDark) {
    final options = [
      {'minutes': 0, 'label': 'At time of event'},
      {'minutes': 5, 'label': '5 minutes before'},
      {'minutes': 10, 'label': '10 minutes before'},
      {'minutes': 15, 'label': '15 minutes before'},
      {'minutes': 30, 'label': '30 minutes before'},
      {'minutes': 60, 'label': '1 hour before'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select Reminder',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                ...options.map((opt) {
                  final int val = opt['minutes'] as int;
                  final String label = opt['label'] as String;
                  final bool isSelected = _selectedReminderLead == val;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                    ),
                    title: Text(
                      label,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? const Color(0xFF2563EB) : (isDark ? Colors.white : const Color(0xFF1E293B)),
                      ),
                    ),
                    onTap: () {
                      setState(() => _selectedReminderLead = val);
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.isNew ? 'Add Schedule' : 'Edit Event',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
        actions: [
          if (!widget.isNew)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
              tooltip: 'Delete Event',
              onPressed: _onDelete,
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Field
                    _buildFieldLabel('Title', isDark),
                    TextField(
                      controller: _titleController,
                      maxLength: 100,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: _getTitleHint(),
                        prefixIcon: const Icon(Icons.edit_note_rounded, size: 20, color: Color(0xFF2563EB)),
                        filled: true,
                        fillColor: isDark ? AppColors.surfaceDark : Colors.white,
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

                    const SizedBox(height: 18),

                    // Type / Category Selector (Modern Choice Pills)
                    _buildFieldLabel('Type', isDark),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ScheduleCategory.values.map((cat) {
                        final bool isSelected = _selectedCategory == cat;
                        final Color catColor = cat.color;

                        return GestureDetector(
                          onTap: () => setState(() => _selectedCategory = cat),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? catColor.withValues(alpha: isDark ? 0.25 : 0.12)
                                  : (isDark ? AppColors.surfaceDark : Colors.white),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? catColor : (isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
                                width: isSelected ? 1.8 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  cat.icon,
                                  size: 17,
                                  color: isSelected ? catColor : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  cat.shortLabel,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected ? catColor : (isDark ? Colors.white70 : const Color(0xFF475569)),
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 5),
                                  Icon(Icons.check_rounded, size: 14, color: catColor),
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 18),

                    // Day(s) Selection Pills
                    _buildFieldLabel('Day(s)', isDark),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _weekdays.map((item) {
                        final int day = item['day'];
                        final String name = item['name'];
                        final bool isSelected = _selectedDays.contains(day);

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedDays.remove(day);
                              } else {
                                _selectedDays.add(day);
                                _selectedDays.sort();
                              }
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF2563EB).withValues(alpha: 0.15)
                                  : (isDark ? AppColors.surfaceDark : Colors.white),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF2563EB) : (isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected ? const Color(0xFF2563EB) : (isDark ? Colors.white70 : const Color(0xFF475569)),
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.check_rounded, size: 14, color: Color(0xFF2563EB)),
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 18),

                    // Time Row (Start Time & End Time side-by-side)
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel('Start Time', isDark),
                              GestureDetector(
                                onTap: () => _pickTime(isStart: true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.surfaceDark : Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF2563EB)),
                                      const SizedBox(width: 8),
                                      Text(
                                        TimeUtils.formatTo12Hour(_startTime),
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel('End Time', isDark),
                              GestureDetector(
                                onTap: () => _pickTime(isStart: false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.surfaceDark : Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.access_time_filled_rounded, size: 16, color: Color(0xFF2563EB)),
                                      const SizedBox(width: 8),
                                      Text(
                                        TimeUtils.formatTo12Hour(_endTime),
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Crosses midnight / Overnight Toggle Switch
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.nightlight_round,
                                size: 18,
                                color: _spansNextDay ? const Color(0xFF8B5CF6) : (isDark ? Colors.white54 : const Color(0xFF94A3B8)),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Crosses midnight / Overnight',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    'Shift or class ends on the next calendar day',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Switch.adaptive(
                            value: _spansNextDay,
                            activeThumbColor: const Color(0xFF8B5CF6),
                            onChanged: (val) => setState(() => _spansNextDay = val),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Location / Branch / Station
                    _buildFieldLabel(_getLocationLabel(), isDark),
                    TextField(
                      controller: _locationController,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                      decoration: InputDecoration(
                        hintText: _getLocationHint(),
                        prefixIcon: const Icon(Icons.location_on_outlined, size: 20, color: Color(0xFF2563EB)),
                        filled: true,
                        fillColor: isDark ? AppColors.surfaceDark : Colors.white,
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

                    const SizedBox(height: 18),

                    // Universal Person-In-Charge / Supervisor / Instructor
                    _buildFieldLabel(_getInChargeLabel(), isDark),
                    TextField(
                      controller: _inChargeController,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                      decoration: InputDecoration(
                        hintText: _getInChargeHint(),
                        prefixIcon: Icon(_getInChargeIcon(), size: 20, color: const Color(0xFF2563EB)),
                        filled: true,
                        fillColor: isDark ? AppColors.surfaceDark : Colors.white,
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

                    const SizedBox(height: 18),

                    // Reminder (Modern Tap Selector with Bottom Sheet)
                    _buildFieldLabel('Reminder', isDark),
                    GestureDetector(
                      onTap: () => _showReminderPicker(isDark),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceDark : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.notifications_active_outlined, size: 18, color: Color(0xFF2563EB)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _getReminderLabel(_selectedReminderLead),
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Additional Notes (Optional)
                    _buildFieldLabel('Additional Notes (optional)', isDark),
                    TextField(
                      controller: _notesController,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'e.g. Bring ID, wear uniform, or special tasks...',
                        filled: true,
                        fillColor: isDark ? AppColors.surfaceDark : Colors.white,
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

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),

            // Bottom Save Changes Button
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
                child: ElevatedButton(
                  onPressed: _onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(
                    widget.isNew ? 'Add to Schedule' : 'Save Changes',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
}

  Widget _buildFieldLabel(String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.textSecondaryDark : const Color(0xFF475569),
        ),
      ),
    );
  }
}
