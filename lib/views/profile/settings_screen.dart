import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/utils/page_transitions.dart';
import '../../providers/sound_settings_provider.dart';
import '../onboarding/workspace_setup_screen.dart';
import '../settings/ai_settings_view.dart';
import '../settings/battery_optimization_view.dart';
import '../settings/widgets/alarm_tone_picker_modal.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _defaultReminderLead = 15;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section 1: Alarms & Notifications
              _buildSectionHeader('ALARMS & NOTIFICATIONS', isDark),
              Container(
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
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.timelapse_rounded, color: Color(0xFF8B5CF6), size: 20),
                      ),
                      title: const Text(
                        'Default Reminder Lead Time',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                      ),
                      subtitle: Text(
                        '$_defaultReminderLead minutes before scheduled event',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatMinutesLabel(_defaultReminderLead),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF2563EB)),
                          ],
                        ),
                      ),
                      onTap: () => _showReminderLeadPicker(context, isDark),
                    ),
                    _buildSubtleDivider(isDark),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.music_note_rounded, color: Color(0xFFF59E0B), size: 20),
                      ),
                      title: const Text(
                        'Alarm Sound & Tone',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                      ),
                      subtitle: Text(
                        ref.watch(soundSettingsProvider).selectedTone.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              ref.watch(soundSettingsProvider).selectedTone.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF2563EB)),
                          ],
                        ),
                      ),
                      onTap: () => AlarmTonePickerModal.show(context),
                    ),
                    _buildSubtleDivider(isDark),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.notification_add_rounded, color: Color(0xFF10B981), size: 20),
                      ),
                      title: const Text(
                        'Test Alarm & Notification',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                      ),
                      subtitle: Text(
                        'Send an instant high-priority alarm & status bar test',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Test Now',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ),
                      onTap: () async {
                        await NotificationService().showTestNotification();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Test alarm sent! Check your status bar and alarm sound.'),
                              duration: Duration(seconds: 3),
                              backgroundColor: Color(0xFF10B981),
                            ),
                          );
                        }
                      },
                    ),
                    _buildSubtleDivider(isDark),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.battery_alert_rounded, color: Color(0xFFEF4444), size: 20),
                      ),
                      title: const Text(
                        'Battery & Background Guide',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                      ),
                      subtitle: Text(
                        'Keep alarms running on Xiaomi, Samsung, Oppo & Vivo',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                      onTap: () {
                        Navigator.push(
                          context,
                          SmoothSlideFadeRoute(page: const BatteryOptimizationView()),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Section 2: Display & Calendar Preferences
              _buildSectionHeader('DISPLAY & TIMETABLE PREFERENCES', isDark),
              Container(
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
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.schedule_rounded, color: Color(0xFFF59E0B), size: 20),
                      ),
                      title: const Text(
                        'Time Display Format',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                      ),
                      subtitle: Text(
                        '12-Hour AM/PM (e.g. 8:30 AM – 10:00 AM)',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                        ),
                      ),
                      trailing: const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 20),
                    ),
                    _buildSubtleDivider(isDark),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.calendar_view_week_rounded, color: Color(0xFF3B82F6), size: 20),
                      ),
                      title: const Text(
                        'First Day of Week',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                      ),
                      subtitle: Text(
                        'Monday',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                        ),
                      ),
                      trailing: const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 20),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Section 3: Workspace & Onboarding
              _buildSectionHeader('WORKSPACE & ONBOARDING', isDark),
              Container(
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
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.tune_rounded, color: Color(0xFF2563EB), size: 20),
                      ),
                      title: const Text(
                        'Re-launch Workspace Setup',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                      ),
                      subtitle: Text(
                        'Change school, workplace, region, or alarm ringtone',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                      onTap: () {
                        Navigator.push(
                          context,
                          SmoothSlideFadeRoute(page: const WorkspaceSetupScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Section 4: AI Engines & API Keys
              _buildSectionHeader('AI ENGINES & SCANNER', isDark),
              Container(
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
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.hub_rounded, color: Color(0xFF8B5CF6), size: 20),
                      ),
                      title: const Text(
                        'AI Engines & API Keys',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                      ),
                      subtitle: Text(
                        'Configure Groq, Gemini, OpenRouter & Cloudflare AI',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                      onTap: () {
                        Navigator.push(
                          context,
                          SmoothSlideFadeRoute(page: const AiSettingsView()),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    ),
  ),
);
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildSubtleDivider(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(left: 56, right: 16),
      height: 0.8,
      color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
    );
  }

  String _formatMinutesLabel(int minutes) {
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      return '$hours hr${hours > 1 ? 's' : ''}';
    }
    return '$minutes min';
  }

  void _showReminderLeadPicker(BuildContext context, bool isDark) {
    final options = [
      {'val': 5, 'label': '5 minutes before', 'desc': 'Quick alert right before'},
      {'val': 10, 'label': '10 minutes before', 'desc': 'Standard preparation time'},
      {'val': 15, 'label': '15 minutes before', 'desc': 'Recommended for classes & duties'},
      {'val': 30, 'label': '30 minutes before', 'desc': 'Plenty of travel & prep time'},
      {'val': 60, 'label': '1 hour before', 'desc': 'Early heads-up notification'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.borderDark : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Default Reminder Lead Time',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Set how early alarm notifications ring before your schedule starts',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...options.map((opt) {
                    final val = opt['val'] as int;
                    final isSelected = _defaultReminderLead == val;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: InkWell(
                        onTap: () {
                          setState(() => _defaultReminderLead = val);
                          Navigator.pop(ctx);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                                : (isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF2563EB)
                                  : (isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                                size: 22,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      opt['label'] as String,
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                        color: isSelected
                                            ? const Color(0xFF2563EB)
                                            : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      opt['desc'] as String,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
