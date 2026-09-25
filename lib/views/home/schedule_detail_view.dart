import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/page_transitions.dart';
import '../../core/utils/time_utils.dart';
import '../../models/schedule_category.dart';
import '../../models/schedule_entry.dart';
import '../../providers/profile_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/sound_settings_provider.dart';
import '../schedule/add_edit_schedule_view.dart';
import '../schedule/reminder_settings_view.dart';

class ScheduleDetailView extends ConsumerWidget {
  final ScheduleEntry entry;

  const ScheduleDetailView({
    super.key,
    required this.entry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final soundState = ref.watch(soundSettingsProvider);
    final profiles = ref.watch(profileListProvider);
    final allSchedules = ref.watch(scheduleListProvider);

    final liveEntry = allSchedules.cast<ScheduleEntry?>().firstWhere(
          (e) => e?.id == entry.id,
          orElse: () => entry,
        ) ??
        entry;

    final linkedProfile = liveEntry.profileId != null
        ? profiles.cast<dynamic>().firstWhere(
            (p) => p.id == liveEntry.profileId,
            orElse: () => null,
          )
        : null;

    final primaryColor = liveEntry.category.color;
    final durationFormatted = TimeUtils.calculateDuration(
      liveEntry.startTime,
      liveEntry.endTime,
      spansNextDay: liveEntry.spansNextDay,
    );

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Schedule Details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 22),
            tooltip: 'Share Schedule',
            onPressed: () {
              final daysStr = TimeUtils.formatDaysAbbr(liveEntry.daysOfWeek);
              final timeStr =
                  '${TimeUtils.formatTo12Hour(liveEntry.startTime)} – ${TimeUtils.formatTo12Hour(liveEntry.endTime)}';
              final locStr = liveEntry.location != null && liveEntry.location!.isNotEmpty
                  ? '\n📍 Location: ${liveEntry.location}'
                  : '';
              Share.share(
                '📅 ${liveEntry.title}\n🗓️ Days: $daysStr\n⏰ Time: $timeStr$locStr\n\nShared via Reminda',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 22),
            tooltip: 'Delete Schedule',
            onPressed: () => _confirmDelete(context, ref, liveEntry),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1D4ED8), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () async {
                  final updated = await Navigator.push<bool>(
                    context,
                    SmoothSlideFadeRoute(
                      page: AddEditScheduleView(initialEntry: liveEntry),
                    ),
                  );
                  if (updated == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Schedule updated successfully!'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Color(0xFF16A34A),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                label: const Text(
                  'Edit Schedule',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 1. Hero Title Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        primaryColor.withValues(alpha: 0.2),
                        AppColors.surfaceDark,
                      ]
                    : [
                        primaryColor.withValues(alpha: 0.08),
                        Colors.white,
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: primaryColor.withValues(alpha: isDark ? 0.3 : 0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: isDark ? 0.15 : 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Tags
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(liveEntry.category.icon, size: 14, color: primaryColor),
                          const SizedBox(width: 5),
                          Text(
                            liveEntry.category.displayName.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (linkedProfile != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceDark : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? AppColors.borderDark : const Color(0xFFCBD5E1),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          linkedProfile.name,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.textSecondaryDark : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: liveEntry.isActive
                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                            : const Color(0xFF64748B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: liveEntry.isActive ? const Color(0xFF10B981) : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            liveEntry.isActive ? 'Active' : 'Muted',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: liveEntry.isActive ? const Color(0xFF10B981) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Main Title
                Text(
                  liveEntry.title,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),

                // Duration & Room Badges
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined, size: 15, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          '$durationFormatted Duration',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    if (liveEntry.location != null && liveEntry.location!.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFF2563EB)),
                          const SizedBox(width: 3),
                          Text(
                            liveEntry.location!,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. Schedule Timing & Weekdays Card
          _buildSectionTitle('DATE & TIMING', isDark),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time Range
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.access_time_filled_rounded, color: Color(0xFF2563EB), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Schedule Hours',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${TimeUtils.formatTo12Hour(liveEntry.startTime)}  →  ${TimeUtils.formatTo12Hour(liveEntry.endTime)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    if (liveEntry.spansNextDay) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Overnight',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFD97706)),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Weekday Badges
                Text(
                  'Active Days of Week',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildWeekdayCircle(1, 'M', 'Mon', liveEntry.daysOfWeek, isDark),
                    _buildWeekdayCircle(2, 'T', 'Tue', liveEntry.daysOfWeek, isDark),
                    _buildWeekdayCircle(3, 'W', 'Wed', liveEntry.daysOfWeek, isDark),
                    _buildWeekdayCircle(4, 'TH', 'Thu', liveEntry.daysOfWeek, isDark),
                    _buildWeekdayCircle(5, 'F', 'Fri', liveEntry.daysOfWeek, isDark),
                    _buildWeekdayCircle(6, 'S', 'Sat', liveEntry.daysOfWeek, isDark),
                    _buildWeekdayCircle(7, 'SU', 'Sun', liveEntry.daysOfWeek, isDark),
                  ],
                ),
                if (liveEntry.nextOccurrenceDate() != null) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  Builder(
                    builder: (context) {
                      final nextDate = liveEntry.nextOccurrenceDate()!;
                      final nextIso = ScheduleEntry.dateToIso(nextDate);
                      final isSkipped = liveEntry.mutedDates.contains(nextIso);
                      final formattedDate = TimeUtils.formatShortDate(nextDate);

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSkipped
                              ? const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.14 : 0.08)
                              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSkipped
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.45)
                                : (isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSkipped ? Icons.event_busy_rounded : Icons.beach_access_rounded,
                              size: 20,
                              color: isSkipped ? const Color(0xFFD97706) : const Color(0xFF2563EB),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isSkipped
                                        ? 'Skipped on $formattedDate'
                                        : 'Holiday / No Class on $formattedDate?',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: isSkipped
                                          ? const Color(0xFFD97706)
                                          : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isSkipped
                                        ? 'Alarms muted for this date only. Resumes automatically next week.'
                                        : 'Skip next alarm without turning off your weekly schedule.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () async {
                                final nowMuted = await ref
                                    .read(scheduleListProvider.notifier)
                                    .toggleMuteDate(liveEntry.id, nextIso);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      nowMuted
                                          ? 'Skipped alarm for $formattedDate. Will ring again next week!'
                                          : 'Restored alarm for $formattedDate.',
                                    ),
                                    backgroundColor:
                                        nowMuted ? const Color(0xFFD97706) : const Color(0xFF10B981),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                backgroundColor: isSkipped
                                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                    : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                isSkipped ? 'Restore' : 'Skip Next',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: isSkipped ? const Color(0xFF10B981) : const Color(0xFFD97706),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 3. Smart Alarm & Ringtone Hub
          _buildSectionTitle('SMART ALARM & NOTIFICATIONS', isDark),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF8B5CF6), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Alarm Ringtone',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            soundState.selectedTone.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Sound Preview Play Button
                    IconButton(
                      icon: Icon(
                        soundState.playingToneId == soundState.selectedToneId
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_filled_rounded,
                        color: const Color(0xFF8B5CF6),
                        size: 32,
                      ),
                      tooltip: 'Play Ringtone Audio',
                      onPressed: () {
                        ref.read(soundSettingsProvider.notifier).playPreview(soundState.selectedToneId);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Reminders List Header & Wrap
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ACTIVE REMINDERS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          SmoothSlideFadeRoute(
                            page: ReminderSettingsView(entry: liveEntry),
                          ),
                        );
                      },
                      icon: const Icon(Icons.tune_rounded, size: 15, color: Color(0xFF2563EB)),
                      label: const Text(
                        'Edit Alarms',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: liveEntry.reminders.isEmpty
                      ? [
                          Text(
                            'No alarms set for this schedule.',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontStyle: FontStyle.italic,
                              color: isDark ? AppColors.textSecondaryDark : const Color(0xFF94A3B8),
                            ),
                          ),
                        ]
                      : liveEntry.reminders.map((lead) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.alarm_on_rounded, size: 14, color: Color(0xFF2563EB)),
                                const SizedBox(width: 4),
                                Text(
                                  TimeUtils.formatLeadMinutes(lead),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 4. Venue & Instructor Remarks Card
          _buildSectionTitle('VENUE & INSTRUCTOR REMARKS', isDark),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Room / Location Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.meeting_room_rounded, color: Color(0xFF2563EB), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Room / Venue',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            liveEntry.location != null && liveEntry.location!.trim().isNotEmpty
                                ? liveEntry.location!
                                : 'No room specified',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),

                // 2. Instructor / Teacher & Notes Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person_rounded, color: Color(0xFF8B5CF6), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Teacher / Instructor & Remarks',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            liveEntry.notes != null && liveEntry.notes!.trim().isNotEmpty
                                ? liveEntry.notes!
                                : 'No teacher or remarks added.',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              fontWeight: FontWeight.w700,
                              color: liveEntry.notes != null && liveEntry.notes!.trim().isNotEmpty
                                  ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                  : (isDark ? AppColors.textSecondaryDark : const Color(0xFF94A3B8)),
                              fontStyle: liveEntry.notes != null && liveEntry.notes!.trim().isNotEmpty
                                  ? FontStyle.normal
                                  : FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildWeekdayCircle(int dayNumber, String shortLabel, String fullLabel, List<int> activeDays, bool isDark) {
    final isActive = activeDays.contains(dayNumber);

    return Container(
      width: 38,
      height: 44,
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF2563EB)
            : (isDark ? AppColors.backgroundDark : const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive
              ? const Color(0xFF2563EB)
              : (isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
          width: 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          shortLabel,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: isActive
                ? Colors.white
                : (isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, ScheduleEntry targetEntry) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Delete Schedule',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${targetEntry.title}"? This action cannot be undone.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : const Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              // BUG FIX (Critical #4): Capture the messenger BEFORE any pop()
              // calls. Navigator.pop() deactivates `context`, so calling
              // ScaffoldMessenger.of(context) afterwards crashes with:
              // "Looking up a deactivated widget's ancestor is unsafe".
              final messenger = ScaffoldMessenger.of(context);
              ref.read(scheduleListProvider.notifier).deleteSchedule(targetEntry);
              Navigator.pop(ctx); // Close confirmation dialog
              Navigator.pop(context); // Close detail screen
              messenger.showSnackBar(
                SnackBar(
                  content: Text('Deleted "${targetEntry.title}"'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 5),
                  action: SnackBarAction(
                    label: 'UNDO',
                    textColor: Colors.amberAccent,
                    onPressed: () {
                      ref.read(scheduleListProvider.notifier).addSchedule(targetEntry);
                    },
                  ),
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

