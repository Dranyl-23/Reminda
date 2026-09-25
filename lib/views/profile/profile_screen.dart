import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/user_setup_provider.dart';
import '../onboarding/login_screen.dart';
import '../profiles/schedule_profiles_view.dart';
import '../schedule/manage_all_schedules_view.dart';
import 'about_schedly_view.dart';
import 'help_support_view.dart';
import 'send_feedback_view.dart';
import 'settings_screen.dart';
import 'user_profile_detail_view.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isSyncing = false;

  void _onLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 24),
            SizedBox(width: 10),
            Text('Log Out', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        content: const Text('Are you sure you want to log out of your Reminda account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authProvider.notifier).logout();
      await ref.read(userSetupProvider.notifier).reset();
      ref.read(scheduleListProvider.notifier).clearLocalMemory();
      ref.read(profileListProvider.notifier).clearLocalMemory();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _onBackupAndSync() async {
    final auth = ref.read(authProvider);
    if (auth.isGuest) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    setState(() => _isSyncing = true);
    await ref.read(scheduleListProvider.notifier).refreshFromCloud();
    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Schedules synced with Cloud Backup!'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
    }
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return 'U';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'More',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            // User Profile Card (Clickable to open detailed profile view)
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UserProfileDetailView()),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(16),
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
                child: Row(
                  children: [
                    // User Avatar: Google Profile Photo if available, else Initials
                    _buildUserAvatar(auth, isDark),

                    const SizedBox(width: 14),

                    // Name & Email
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auth.userName,
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            auth.isGuest ? 'guest@reminda.app' : auth.userEmail,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Icon(
                      Icons.chevron_right_rounded,
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Grouped Navigation Card matching user mockup with clean subtle dividers
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
                  // Item 1: My Profiles
                  _buildNavTile(
                    icon: Icons.people_outline_rounded,
                    title: 'My Profiles',
                    subtitle: 'Manage different schedules',
                    isDark: isDark,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ScheduleProfilesView()),
                      );
                    },
                  ),
                  _buildSubtleDivider(isDark),

                  // Item 2: My Schedules
                  _buildNavTile(
                    icon: Icons.calendar_month_outlined,
                    title: 'My Schedules',
                    subtitle: 'View and manage all schedules',
                    isDark: isDark,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ManageAllSchedulesView()),
                      );
                    },
                  ),
                  _buildSubtleDivider(isDark),

                  // Item 3: Settings
                  _buildNavTile(
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    subtitle: 'Notifications, reminders, theme',
                    isDark: isDark,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                    },
                  ),
                  _buildSubtleDivider(isDark),

                  // Item 4: Backup & Sync
                  _buildNavTile(
                    icon: Icons.cloud_outlined,
                    title: 'Backup & Sync',
                    subtitle: 'Sync your schedules to cloud',
                    isDark: isDark,
                    trailingWidget: _isSyncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    onTap: _onBackupAndSync,
                  ),
                  _buildSubtleDivider(isDark),

                  // Item 5: Help & Support
                  _buildNavTile(
                    icon: Icons.help_outline_rounded,
                    title: 'Help & Support',
                    subtitle: 'FAQs and device troubleshooting',
                    isDark: isDark,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HelpSupportView()),
                      );
                    },
                  ),
                  _buildSubtleDivider(isDark),

                  // Item 6: Send Feedback
                  _buildNavTile(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Send Feedback',
                    subtitle: 'Report a bug or suggest features',
                    isDark: isDark,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SendFeedbackView()),
                      );
                    },
                  ),
                  _buildSubtleDivider(isDark),

                  // Item 7: About
                  _buildNavTile(
                    icon: Icons.info_outline_rounded,
                    title: 'About',
                    subtitle: 'Reminda v1.0.0',
                    isDark: isDark,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AboutSchedlyView()),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Log Out Button (if logged in)
            if (!auth.isGuest) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _onLogout,
                  icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 18),
                  label: const Text(
                    'Log Out',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    backgroundColor: const Color(0xFFFEF2F2),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildNavTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
    Widget? trailingWidget,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isDark ? Colors.white70 : const Color(0xFF1E293B),
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
        ),
      ),
      trailing: trailingWidget ??
          const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: Color(0xFF94A3B8),
          ),
      onTap: onTap,
    );
  }

  Widget _buildUserAvatar(dynamic auth, bool isDark) {
    final String? photoUrl = auth.userPhotoUrl as String?;
    if (photoUrl != null && photoUrl.trim().isNotEmpty) {
      Widget imageWidget;
      if (photoUrl.startsWith('data:image/')) {
        try {
          final commaIdx = photoUrl.indexOf(',');
          final rawBase64 = commaIdx != -1 ? photoUrl.substring(commaIdx + 1) : photoUrl;
          imageWidget = Image.memory(
            base64Decode(rawBase64),
            fit: BoxFit.cover,
            width: 52,
            height: 52,
            errorBuilder: (context, error, stackTrace) => _buildInitialsAvatar(auth.userName),
          );
        } catch (_) {
          imageWidget = _buildInitialsAvatar(auth.userName);
        }
      } else {
        imageWidget = Image.network(
          photoUrl,
          fit: BoxFit.cover,
          width: 52,
          height: 52,
          errorBuilder: (context, error, stackTrace) => _buildInitialsAvatar(auth.userName),
        );
      }

      return Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF2563EB), width: 1.5),
        ),
        child: ClipOval(child: imageWidget),
      );
    }
    return _buildInitialsAvatar(auth.userName);
  }

  Widget _buildInitialsAvatar(String name) {
    return Container(
      width: 52,
      height: 52,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF0F3BB8),
      ),
      child: Center(
        child: Text(
          _getInitials(name),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSubtleDivider(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(left: 68, right: 16),
      height: 0.8,
      color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
    );
  }
}
