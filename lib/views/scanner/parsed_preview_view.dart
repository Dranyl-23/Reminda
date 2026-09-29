import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/time_utils.dart';
import '../../models/schedule_category.dart';
import '../../models/schedule_entry.dart';
import '../../providers/schedule_provider.dart';

class ParsedPreviewView extends ConsumerStatefulWidget {
  final List<ScheduleEntry> entries;

  const ParsedPreviewView({
    super.key,
    required this.entries,
  });

  @override
  ConsumerState<ParsedPreviewView> createState() => _ParsedPreviewViewState();
}

class _ParsedPreviewViewState extends ConsumerState<ParsedPreviewView> {
  late List<ScheduleEntry> _items;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.entries);
  }

  void _removeEntry(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _editEntry(int index) async {
    final entry = _items[index];
    final titleController = TextEditingController(text: entry.title);
    final locationController = TextEditingController(text: entry.location ?? '');

    final updated = await showDialog<ScheduleEntry>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Extracted Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(labelText: 'Location / Room'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(
                context,
                entry.copyWith(
                  title: titleController.text.trim(),
                  location: locationController.text.trim().isNotEmpty
                      ? locationController.text.trim()
                      : null,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).whenComplete(() {
      titleController.dispose();
      locationController.dispose();
    });

    if (updated != null) {
      setState(() {
        _items[index] = updated;
      });
    }
  }

  Future<void> _saveAll() async {
    if (_items.isEmpty) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    await ref.read(scheduleListProvider.notifier).importBatch(_items);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully added ${_items.length} schedule entries!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  int _parseTimeToMinutes(String time) {
    final parts = time.split(':');
    if (parts.length >= 2) {
      return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Group items by weekday for the display
    final Map<int, List<ScheduleEntry>> grouped = {};
    for (int day = 1; day <= 7; day++) {
      final matches = _items.where((e) => e.daysOfWeek.contains(day)).toList();
      if (matches.isNotEmpty) {
        grouped[day] = matches..sort((a, b) => _parseTimeToMinutes(a.startTime).compareTo(_parseTimeToMinutes(b.startTime)));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parsed Schedule'),
      ),
      bottomNavigationBar: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _items.isEmpty ? null : _saveAll,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Save Schedule (${_items.length} Entries)',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
  body: _items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_busy_rounded,
                    size: 56,
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No schedule entries remaining',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: ListView(
                  padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Review and edit the extracted entries.',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 16),

                ...grouped.entries.map((group) {
                  final dayName = TimeUtils.getWeekdayFull(group.key);
                  final dayEntries = group.value;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          dayName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.textPrimaryDark : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      ...dayEntries.map((entry) {
                        final originalIndex = _items.indexOf(entry);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceDark : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: entry.category.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.title,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${TimeUtils.formatTo12Hour(entry.startTime)} – ${TimeUtils.formatTo12Hour(entry.endTime)}${entry.location != null ? " • ${entry.location}" : ""}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? AppColors.textSecondaryDark
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                onPressed: () {
                                  if (originalIndex != -1) {
                                    _editEntry(originalIndex);
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: AppColors.error,
                                ),
                                onPressed: () {
                                  if (originalIndex != -1) {
                                    _removeEntry(originalIndex);
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
    );
  }
}
