import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/time_utils.dart';
import '../../models/schedule_entry.dart';
import '../../providers/auth_provider.dart';
import '../../providers/filter_providers.dart';
import '../../providers/notification_center_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/user_setup_provider.dart';
import '../navigation/main_navigation_shell.dart';
import '../scanner/scanner_landing_view.dart';
import '../schedule/add_edit_schedule_view.dart';
import '../schedule/widgets/add_schedule_modal_dialog.dart';
import 'notifications_screen.dart';
import 'schedule_detail_view.dart';
import 'widgets/announcement_banner.dart';
import 'widgets/schedule_card.dart';
import 'widgets/schedule_summary_modal.dart';
import 'widgets/upcoming_banner.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final isDesktop = mediaQuery.size.width >= 900;
    final auth = ref.watch(authProvider);
    final schedules = ref.watch(schedulesForTodayProvider);
    final allSchedules = ref.watch(scheduleListProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    final userSetup = ref.watch(userSetupProvider);

    String todaySectionTitle;
    String noTodayTitle;
    String upcomingRoleNoun;

    switch (userSetup.role.toLowerCase()) {
      case 'duty':
      case 'medic':
      case 'nurs':
        todaySectionTitle = "TODAY'S CLINICAL DUTY";
        noTodayTitle = 'No duty shifts scheduled for today';
        upcomingRoleNoun = 'clinical duty';
        break;
      case 'work':
      case 'job':
      case 'part':
        todaySectionTitle = "TODAY'S WORK SHIFTS";
        noTodayTitle = 'No work shifts scheduled for today';
        upcomingRoleNoun = 'work shift';
        break;
      case 'personal':
      case 'custom':
        todaySectionTitle = "TODAY'S TIMETABLE";
        noTodayTitle = 'No scheduled routine for today';
        upcomingRoleNoun = 'routine';
        break;
      default:
        todaySectionTitle = "TODAY'S SCHEDULE";
        noTodayTitle = 'No classes scheduled for today';
        upcomingRoleNoun = 'class';
    }

    // Extract first name (e.g. "Alfie" or "Dranyl")
    final firstName = auth.userName.trim().split(' ').first;
    final greeting = '${TimeUtils.getGreeting()}, $firstName!';
    final fullFormattedDate = DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: isDesktop
            ? null
            : IconButton(
                icon: const Icon(Icons.menu_rounded, size: 24),
                tooltip: 'Schedule Insights & Export',
                onPressed: () {
                  ScheduleSummaryModal.show(context);
                },
              ),
        title: isDesktop
            ? Row(
                children: [
                  Text(
                    'Dashboard',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF1E3A8A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      DateFormat('EEE, MMM d').format(DateTime.now()),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              )
            : const Text(
                'Reminda',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E3A8A),
                  letterSpacing: -0.3,
                ),
              ),
        centerTitle: !isDesktop,
        elevation: 0,
        backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
        actions: [
          if (isDesktop) ...[
            TextButton.icon(
              onPressed: () => AddScheduleModalDialog.show(context),
              icon: const Icon(Icons.add_rounded, size: 18, color: Color(0xFF2563EB)),
              label: const Text(
                'Add Schedule',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2563EB),
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Schedule Insights & Export',
              icon: const Icon(Icons.insights_rounded, size: 21),
              onPressed: () => ScheduleSummaryModal.show(context),
            ),
            const SizedBox(width: 4),
          ],
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none_rounded, size: 24),
                if (unreadCount > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Semantics(
                      label: '$unreadCount unread notifications',
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isDesktop
          ? _buildDesktopDashboard(
              context: context,
              ref: ref,
              isDark: isDark,
              greeting: greeting,
              fullFormattedDate: fullFormattedDate,
              todaySectionTitle: todaySectionTitle,
              noTodayTitle: noTodayTitle,
              upcomingRoleNoun: upcomingRoleNoun,
              schedules: schedules,
              allSchedules: allSchedules,
            )
          : _buildMobileDashboard(
              context: context,
              ref: ref,
              isDark: isDark,
              greeting: greeting,
              fullFormattedDate: fullFormattedDate,
              todaySectionTitle: todaySectionTitle,
              noTodayTitle: noTodayTitle,
              upcomingRoleNoun: upcomingRoleNoun,
              schedules: schedules,
            ),
    );
  }

  // ==========================================
  // DESKTOP BENTO LAYOUT (Width >= 900)
  // ==========================================
  Widget _buildDesktopDashboard({
    required BuildContext context,
    required WidgetRef ref,
    required bool isDark,
    required String greeting,
    required String fullFormattedDate,
    required String todaySectionTitle,
    required String noTodayTitle,
    required String upcomingRoleNoun,
    required List<ScheduleEntry> schedules,
    required List<ScheduleEntry> allSchedules,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Main Column (60% width)
              Expanded(
                flex: 60,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Greeting & Date Header
                      _buildGreetingHeader(greeting, fullFormattedDate, isDark),
                      const SizedBox(height: 16),

                      // Hero Next Schedule Banner (Live Countdown)
                      const UpcomingBanner(),
                      const SizedBox(height: 20),

                      // Role-Adaptive Section Header
                      _buildSectionHeader(
                        context: context,
                        ref: ref,
                        title: todaySectionTitle,
                        count: schedules.length,
                      ),
                      const SizedBox(height: 12),

                      // Schedule Cards or Empty State
                      if (schedules.isEmpty)
                        _buildEmptyState(
                          context: context,
                          ref: ref,
                          isDark: isDark,
                          noTodayTitle: noTodayTitle,
                          upcomingRoleNoun: upcomingRoleNoun,
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: schedules.length,
                          itemBuilder: (context, index) {
                            final entry = schedules[index];
                            return ScheduleCard(
                              entry: entry,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ScheduleDetailView(entry: entry),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 24),

              // Right Sidebar Column (40% width)
              Expanded(
                flex: 40,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Remote In-App Announcement Broadcast Banner
                      const AnnouncementBanner(),
                      const SizedBox(height: 16),

                      // Desktop Quick Actions Bento Card
                      _buildDesktopQuickActionsCard(context, ref, isDark),
                      const SizedBox(height: 16),

                      // Desktop Schedule Insights / Stats Card
                      _buildDesktopInsightsCard(context, ref, isDark, allSchedules, schedules),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // MOBILE DASHBOARD (Width < 900)
  // ==========================================
  Widget _buildMobileDashboard({
    required BuildContext context,
    required WidgetRef ref,
    required bool isDark,
    required String greeting,
    required String fullFormattedDate,
    required String todaySectionTitle,
    required String noTodayTitle,
    required String upcomingRoleNoun,
    required List<ScheduleEntry> schedules,
  }) {
    return CustomScrollView(
      slivers: [
        // Greeting & Date Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: _buildGreetingHeader(greeting, fullFormattedDate, isDark),
          ),
        ),

        // Remote In-App Announcement Broadcast Banner
        const SliverToBoxAdapter(
          child: AnnouncementBanner(),
        ),

        // Hero Next Schedule Banner (with Live Dynamic Countdown across any day)
        const SliverToBoxAdapter(
          child: UpcomingBanner(),
        ),

        const SliverToBoxAdapter(
          child: SizedBox(height: 14),
        ),

        // Role-Adaptive Section Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
            child: _buildSectionHeader(
              context: context,
              ref: ref,
              title: todaySectionTitle,
              count: schedules.length,
            ),
          ),
        ),

        // Schedule List or Empty State
        if (schedules.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: _buildEmptyState(
                  context: context,
                  ref: ref,
                  isDark: isDark,
                  noTodayTitle: noTodayTitle,
                  upcomingRoleNoun: upcomingRoleNoun,
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 80),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final entry = schedules[index];
                  return ScheduleCard(
                    entry: entry,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ScheduleDetailView(entry: entry),
                        ),
                      );
                    },
                  );
                },
                childCount: schedules.length,
              ),
            ),
          ),
      ],
    );
  }

  // ==========================================
  // SHARED SUB-COMPONENTS
  // ==========================================

  Widget _buildGreetingHeader(String greeting, String fullFormattedDate, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          fullFormattedDate,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required int count,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: Color(0xFF1E3A8A),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ],
        ),
        Semantics(
          button: true,
          label: 'View all schedules',
          child: GestureDetector(
            onTap: () {
              ref.read(navigationIndexProvider.notifier).state = 1; // Switch to Calendar / Timetable tab
            },
            child: const Text(
              'View all',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2563EB),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required BuildContext context,
    required WidgetRef ref,
    required bool isDark,
    required String noTodayTitle,
    required String upcomingRoleNoun,
  }) {
    final nextUpcoming = ref.watch(nextUpcomingAcrossAllDaysProvider);

    if (nextUpcoming != null) {
      final dayText = nextUpcoming.daysDifference == 1
          ? 'Tomorrow'
          : DateFormat('EEEE, MMM d').format(nextUpcoming.targetDateTime);

      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_available_rounded,
              size: 48,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            noTodayTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Your upcoming $upcomingRoleNoun for "${nextUpcoming.entry.title}" starts on $dayText at ${TimeUtils.formatTo12Hour(nextUpcoming.entry.startTime)}.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.calendar_today_rounded,
            size: 48,
            color: Color(0xFF2563EB),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'No schedules added yet',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Add a schedule to track your classes, duty shifts, and routines.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ==========================================
  // DESKTOP WIDGET: QUICK ACTIONS BENTO CARD
  // ==========================================
  Widget _buildDesktopQuickActionsCard(BuildContext context, WidgetRef ref, bool isDark) {
    return Container(
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
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.bolt_rounded, color: Color(0xFF2563EB), size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'QUICK ACTIONS',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildQuickActionTile(
            icon: Icons.document_scanner_rounded,
            iconColor: const Color(0xFF2563EB),
            title: 'Scan Schedule Document',
            subtitle: 'Extract classes & shifts from photo or digital PDF',
            isDark: isDark,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScannerLandingView()),
              );
            },
          ),
          const SizedBox(height: 8),
          _buildQuickActionTile(
            icon: Icons.edit_calendar_rounded,
            iconColor: const Color(0xFF7C3AED),
            title: 'Add Entry Manually',
            subtitle: 'Create a custom class, clinical duty, or shift',
            isDark: isDark,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddEditScheduleView()),
              );
            },
          ),
          const SizedBox(height: 8),
          _buildQuickActionTile(
            icon: Icons.calendar_month_rounded,
            iconColor: const Color(0xFF059669),
            title: 'Open Weekly Timetable',
            subtitle: 'Inspect full 7-day schedule grid',
            isDark: isDark,
            onTap: () {
              ref.read(navigationIndexProvider.notifier).state = 1;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: Semantics(
        button: true,
        label: title,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.borderDark : const Color(0xFFF1F5F9),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: isDark ? AppColors.textSecondaryDark : const Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  // ==========================================
  // DESKTOP WIDGET: SCHEDULE STATS & INSIGHTS CARD
  // ==========================================
  Widget _buildDesktopInsightsCard(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    List<ScheduleEntry> allSchedules,
    List<ScheduleEntry> todaySchedules,
  ) {
    final activeEntries = allSchedules.where((s) => s.isActive).toList();
    final activeProfile = ref.watch(activeProfileProvider);

    int totalWeeklyMinutes = 0;
    for (final s in activeEntries) {
      final startMin = TimeUtils.timeToMinutes(s.startTime);
      int endMin = TimeUtils.timeToMinutes(s.endTime);
      if (s.spansNextDay || endMin < startMin) endMin += 24 * 60;
      final duration = endMin - startMin;
      totalWeeklyMinutes += duration * s.daysOfWeek.length;
    }
    final totalWeeklyHours = (totalWeeklyMinutes / 60).toStringAsFixed(1);

    return Container(
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
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.insights_rounded, color: Color(0xFF10B981), size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'WEEKLY INSIGHTS',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                ],
              ),
              if (activeProfile != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: activeProfile.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    activeProfile.name,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: activeProfile.color,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInsightMetric(
                  label: 'Active Schedules',
                  value: '${activeEntries.length}',
                  unit: 'entries',
                  color: const Color(0xFF2563EB),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInsightMetric(
                  label: 'Weekly Workload',
                  value: totalWeeklyHours,
                  unit: 'hours / wk',
                  color: const Color(0xFF7C3AED),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => ScheduleSummaryModal.show(context),
              icon: const Icon(Icons.file_download_outlined, size: 16),
              label: const Text(
                'Export Timetable Summary',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                side: const BorderSide(color: Color(0xFFBFDBFE)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightMetric({
    required String label,
    required String value,
    required String unit,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
