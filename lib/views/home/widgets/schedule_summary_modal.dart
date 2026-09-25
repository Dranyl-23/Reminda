import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/schedule_share_service.dart';
import '../../../core/utils/time_utils.dart';
import '../../../models/schedule_entry.dart';
import '../../../providers/schedule_provider.dart';
import '../../scanner/review_scanned_schedules_view.dart';

class ScheduleSummaryModal extends ConsumerWidget {
  const ScheduleSummaryModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ScheduleSummaryModal(),
    );
  }

  int _timeToMinutes(String timeStr) {
    try {
      final parts = timeStr.split(':');
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    } catch (_) {
      return 0;
    }
  }

  String _generateTextSummary(List<ScheduleEntry> schedules) {
    final buffer = StringBuffer();
    buffer.writeln('REMINDA TIMETABLE SUMMARY');
    buffer.writeln('===========================');

    final weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];

    for (int day = 1; day <= 7; day++) {
      final dayEntries = schedules.where((e) => e.daysOfWeek.contains(day)).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));

      if (dayEntries.isNotEmpty) {
        buffer.writeln('\n${weekdays[day - 1].toUpperCase()}:');
        for (final entry in dayEntries) {
          final room = entry.location != null && entry.location!.isNotEmpty
              ? ' (${entry.location})'
              : '';
          buffer.writeln('  • ${TimeUtils.formatTo12Hour(entry.startTime)} - ${TimeUtils.formatTo12Hour(entry.endTime)} : ${entry.title}$room');
        }
      }
    }

    buffer.writeln('\n===========================');
    buffer.writeln('Generated via Reminda');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final schedules = ref.watch(scheduleListProvider);

    // 1. Calculate stats
    int totalWeeklyMinutes = 0;
    final Map<int, int> dayMinutes = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};

    for (final s in schedules) {
      if (!s.isActive) continue;
      final startMin = _timeToMinutes(s.startTime);
      int endMin = _timeToMinutes(s.endTime);
      if (s.spansNextDay || endMin < startMin) endMin += 24 * 60;
      final duration = endMin - startMin;

      for (final d in s.daysOfWeek) {
        dayMinutes[d] = (dayMinutes[d] ?? 0) + duration;
        totalWeeklyMinutes += duration;
      }
    }

    final totalHours = (totalWeeklyMinutes / 60).toStringAsFixed(1);
    final activeCount = schedules.where((s) => s.isActive).length;

    // Find busiest and lightest active days
    int maxMins = 0;
    int maxDay = 1;
    dayMinutes.forEach((day, mins) {
      if (mins > maxMins) {
        maxMins = mins;
        maxDay = day;
      }
    });

    final busiestDayName = maxMins > 0 ? TimeUtils.getWeekdayFull(maxDay) : 'None';
    final busiestDayHours = (maxMins / 60).toStringAsFixed(1);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? AppColors.borderDark : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekly Summary & Insights',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Workload analysis & export tools',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 2x2 Metric Cards Grid
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Total Weekly Time',
                  value: '$totalHours hrs',
                  subtitle: 'Across active events',
                  icon: Icons.timer_outlined,
                  color: const Color(0xFF2563EB),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'Active Schedules',
                  value: '$activeCount sets',
                  subtitle: 'Classes & duties',
                  icon: Icons.event_note_outlined,
                  color: const Color(0xFF7C3AED),
                  isDark: isDark,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Busiest Day',
                  value: busiestDayName,
                  subtitle: maxMins > 0 ? '$busiestDayHours hrs scheduled' : 'No classes',
                  icon: Icons.local_fire_department_rounded,
                  color: const Color(0xFFF59E0B),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'Schedule Health',
                  value: activeCount > 0 ? 'Optimal' : 'Empty',
                  subtitle: 'Balanced load',
                  icon: Icons.verified_outlined,
                  color: const Color(0xFF10B981),
                  isDark: isDark,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Export & Share Action Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1D4ED8), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.share_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Export & Share Timetable',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Copy a formatted text breakdown of your week or share with classmates.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () {
                    final text = _generateTextSummary(schedules);
                    Clipboard.setData(ClipboardData(text: text));
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(context);
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Timetable summary copied to clipboard!'),
                        backgroundColor: Color(0xFF10B981),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF1D4ED8)),
                  label: const Text(
                    'Copy Text Summary to Clipboard',
                    style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _handleGenerateShareCode(context, schedules),
                        icon: const Icon(Icons.qr_code_2_rounded, size: 17, color: Colors.white),
                        label: const Text(
                          'Get 6-Digit Code',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white54, width: 1.3),
                          minimumSize: const Size(0, 42),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _handleImportByShareCode(context),
                        icon: const Icon(Icons.download_rounded, size: 17, color: Colors.white),
                        label: const Text(
                          'Import Code',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white54, width: 1.3),
                          minimumSize: const Size(0, 42),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGenerateShareCode(BuildContext context, List<ScheduleEntry> schedules) async {
    final activeSchedules = schedules.where((e) => e.isActive).toList();
    if (activeSchedules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active schedules to share yet!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    String? shareCode;
    try {
      shareCode = await ScheduleShareService.instance.publishScheduleBundle(
        schedules: activeSchedules,
      );
    } catch (_) {
      shareCode = null;
    }

    if (!context.mounted) return;
    Navigator.pop(context); // Dismiss loading dialog

    if (shareCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not generate share code. Check your internet connection.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final String validCode = shareCode;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_2_rounded, color: AppColors.primary),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '6-Digit Block Code',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share this 6-digit code with your classmates or co-workers so they can import all your active schedules in 1 tap:',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: SelectableText(
                validCode,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Includes ${activeSchedules.length} active class/shift schedules',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: validCode));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Code $validCode copied to clipboard!'),
                  backgroundColor: const Color(0xFF10B981),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy Code', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              Share.share(
                '📚 Import my class/work schedule on Reminda (Schedly)!\n\n'
                '🔑 6-Digit Share Code: $validCode\n'
                '(${activeSchedules.length} schedules included — open Timetable Insights > Import Code)',
                subject: 'Reminda 6-Digit Schedule Code: $validCode',
              );
            },
            icon: const Icon(Icons.share_rounded, size: 16),
            label: const Text('Share', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleImportByShareCode(BuildContext context) async {
    final codeController = TextEditingController();
    final enteredCode = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.download_rounded, color: AppColors.primary),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Import 6-Digit Code',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the 6-digit class block code shared by your classmate or colleague:',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: codeController,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 5,
              ),
              decoration: InputDecoration(
                hintText: '123456',
                counterText: '',
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(dialogCtx, codeController.text.trim()),
            child: const Text('Fetch Schedules', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (enteredCode == null || enteredCode.isEmpty || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    SharedScheduleBundle? bundle;
    try {
      bundle = await ScheduleShareService.instance.fetchByShareCode(enteredCode);
    } catch (_) {
      bundle = null;
    }

    if (!context.mounted) return;
    Navigator.pop(context); // Dismiss loading

    if (bundle == null || bundle.schedules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Code "${enteredCode.toUpperCase()}" not found or has no schedules.'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final validBundle = bundle;
    final navigator = Navigator.of(context);
    navigator.pop(); // Close summary modal
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ReviewScannedSchedulesView(
          initialEntries: validBundle.schedules,
        ),
      ),
    );
  }
}
