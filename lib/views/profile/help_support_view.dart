import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../settings/battery_optimization_view.dart';
import 'send_feedback_view.dart';

class HelpSupportView extends StatelessWidget {
  const HelpSupportView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Help & Support',
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
              // Search / Banner Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
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
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.help_center_rounded, color: Colors.white, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'How can we help you?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Frequently asked questions and guides to help you get the most out of Reminda.',
                      style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.35),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // FAQ Section Header
              _buildSectionHeader('FREQUENTLY ASKED QUESTIONS', isDark),

              // FAQ 1: Scanning
              _buildFaqTile(
                icon: Icons.document_scanner_rounded,
                iconColor: const Color(0xFF2563EB),
                question: 'How do I scan a class schedule or duty roster?',
                answer:
                    'Tap the center "+" button at the bottom navigation bar and select "Scan / Import Schedule". You can take a photo of your printed timetable or upload an image/PDF. Our AI automatically extracts your classes, times, days, and rooms in seconds.',
                isDark: isDark,
              ),

              const SizedBox(height: 10),

              // FAQ 2: Alarms & Background Doze
              _buildFaqTile(
                icon: Icons.alarm_rounded,
                iconColor: const Color(0xFF10B981),
                question: 'Why are alarms not ringing when my phone is asleep?',
                answer:
                    'Android devices (especially Xiaomi, Samsung, Oppo, Vivo) have aggressive battery savers that kill background alarms. Go to Settings > Battery & Alarm Optimization and turn off battery restrictions and grant "Alarms & Reminders" permission.',
                isDark: isDark,
              ),

              const SizedBox(height: 10),

              // FAQ 3: Multiple Profiles
              _buildFaqTile(
                icon: Icons.layers_rounded,
                iconColor: const Color(0xFF8B5CF6),
                question: 'How do I manage multiple schedules (Work & School)?',
                answer:
                    'Tap "My Profiles" in the More screen. You can create separate schedule profiles (e.g. "School Schedule", "Duty Roster", "Part-Time Job") and easily switch active profiles anytime without mixing up your calendar.',
                isDark: isDark,
              ),

              const SizedBox(height: 10),

              // FAQ 4: Cloud Sync & Backup
              _buildFaqTile(
                icon: Icons.cloud_done_rounded,
                iconColor: const Color(0xFF06B6D4),
                question: 'How does Cloud Backup and Sync work?',
                answer:
                    'When you sign in with your Google Account, all your schedules, profiles, and reminders are automatically backed up to private Firebase Firestore cloud storage. Your data syncs instantly across all your devices.',
                isDark: isDark,
              ),

              const SizedBox(height: 24),

              // Device Troubleshooting Guide
              _buildSectionHeader('DEVICE TROUBLESHOOTING', isDark),
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
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.battery_saver_rounded, color: Color(0xFF10B981), size: 22),
                  ),
                  title: Text(
                    'Battery & Alarm Setup Guide',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  subtitle: Text(
                    'Brand-by-brand setup for Xiaomi, Samsung, Oppo & Vivo',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BatteryOptimizationView()),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Feedback Section Header
              _buildSectionHeader('FEEDBACK & SUGGESTIONS', isDark),
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
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEC4899).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFFEC4899), size: 22),
                  ),
                  title: Text(
                    'Send In-App Feedback',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  subtitle: Text(
                    'Report a bug, suggest features or request school additions',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SendFeedbackView()),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Contact Support Card
              _buildSectionHeader('CONTACT SUPPORT', isDark),
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
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Clipboard.setData(const ClipboardData(text: 'alfielynard23@gmail.com'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Support email copied: alfielynard23@gmail.com'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.mail_outline_rounded,
                              color: Color(0xFF2563EB),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Email Support',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'alfielynard23@gmail.com',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.copy_rounded,
                              size: 16,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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

  Widget _buildFaqTile({
    required IconData icon,
    required Color iconColor,
    required String question,
    required String answer,
    required bool isDark,
  }) {
    return Container(
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
      child: Theme(
        data: ThemeData(
          brightness: isDark ? Brightness.dark : Brightness.light,
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: isDark ? Colors.white70 : const Color(0xFF64748B),
          collapsedIconColor: isDark ? Colors.white54 : const Color(0xFF94A3B8),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          title: Text(
            question,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14.5,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          children: [
            Text(
              answer,
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
}
