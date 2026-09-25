import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/database/firestore_instance.dart';
import '../../core/utils/time_utils.dart';
import '../../models/institution_directory.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/user_setup_provider.dart';
import '../onboarding/login_screen.dart';
import '../onboarding/widgets/institution_logo.dart';

class UserProfileDetailView extends ConsumerStatefulWidget {
  const UserProfileDetailView({super.key});

  @override
  ConsumerState<UserProfileDetailView> createState() => _UserProfileDetailViewState();
}

class _UserProfileDetailViewState extends ConsumerState<UserProfileDetailView> {
  bool _isDeleting = false;

  String _getInitials(String name) {
    if (name.trim().isEmpty) return 'U';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  Widget _buildAvatarImage(String? photoUrl, String userName) {
    if (photoUrl == null || photoUrl.trim().isEmpty) {
      return _buildInitialsAvatar(userName);
    }
    if (photoUrl.startsWith('data:image/')) {
      try {
        final commaIdx = photoUrl.indexOf(',');
        final rawBase64 = commaIdx != -1 ? photoUrl.substring(commaIdx + 1) : photoUrl;
        return Image.memory(
          base64Decode(rawBase64),
          fit: BoxFit.cover,
          width: 96,
          height: 96,
          errorBuilder: (context, error, stackTrace) => _buildInitialsAvatar(userName),
        );
      } catch (_) {
        return _buildInitialsAvatar(userName);
      }
    }
    return Image.network(
      photoUrl,
      fit: BoxFit.cover,
      width: 96,
      height: 96,
      errorBuilder: (context, error, stackTrace) => _buildInitialsAvatar(userName),
    );
  }

  Future<void> _changeProfilePhoto() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = ref.read(authProvider);
    final hasPhoto = auth.userPhotoUrl != null && auth.userPhotoUrl!.trim().isNotEmpty;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Update Profile Photo',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Color(0xFF2563EB), size: 20),
                ),
                title: Text(
                  'Choose from Gallery',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                onTap: () => Navigator.pop(ctx, 'gallery'),
              ),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF10B981), size: 20),
                ),
                title: Text(
                  'Take a Photo',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
              if (hasPhoto)
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                  ),
                  title: const Text(
                    'Remove Custom Photo',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                  onTap: () => Navigator.pop(ctx, 'remove'),
                ),
            ],
          ),
        ),
      ),
    );

    if (action == null || !mounted) return;

    if (action == 'remove') {
      await ref.read(authProvider.notifier).updateProfilePhoto(null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile photo reset.'),
          backgroundColor: Color(0xFF2563EB),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final picker = ImagePicker();
    final source = action == 'camera' ? ImageSource.camera : ImageSource.gallery;
    try {
      final XFile? picked = await picker.pickImage(
        source: source,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 75,
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      final dataUri = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      await ref.read(authProvider.notifier).updateProfilePhoto(dataUri);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile photo updated!'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not select photo: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatDays(List<int> days) {
    const dayNames = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};
    return days.map((d) => dayNames[d] ?? '').where((s) => s.isNotEmpty).join(', ');
  }

  void _showExportOptionsSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.file_download_outlined, color: Color(0xFF2563EB), size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Export Schedule Data',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Choose your preferred export format',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Option 1: Formatted Timetable Text
            _buildExportOptionTile(
              context: context,
              icon: Icons.chat_bubble_outline_rounded,
              iconColor: const Color(0xFF2563EB),
              title: 'Share Timetable (Formatted Text)',
              subtitle: 'Clean daily breakdown ready to send on Messenger, Notes, or SMS',
              badge: 'POPULAR',
              badgeColor: const Color(0xFF2563EB),
              onTap: () {
                Navigator.pop(ctx);
                _exportAsFormattedText();
              },
            ),
            const SizedBox(height: 10),

            // Option 2: Excel / Spreadsheet CSV
            _buildExportOptionTile(
              context: context,
              icon: Icons.table_chart_outlined,
              iconColor: const Color(0xFF10B981),
              title: 'Spreadsheet Table (CSV)',
              subtitle: 'Formatted spreadsheet for Microsoft Excel or Google Sheets',
              badge: 'EXCEL',
              badgeColor: const Color(0xFF10B981),
              onTap: () {
                Navigator.pop(ctx);
                _exportAsCsv();
              },
            ),
            const SizedBox(height: 10),

            // Option 3: Full JSON Backup
            _buildExportOptionTile(
              context: context,
              icon: Icons.data_object_rounded,
              iconColor: const Color(0xFF8B5CF6),
              title: 'Full Raw Backup (JSON)',
              subtitle: 'Complete machine-readable file for backup and app data migration',
              badge: 'BACKUP',
              badgeColor: const Color(0xFF8B5CF6),
              onTap: () {
                Navigator.pop(ctx);
                _exportAsJson();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportOptionTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: badgeColor,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.3,
                      color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _exportAsFormattedText() async {
    final auth = ref.read(authProvider);
    final userSetup = ref.read(userSetupProvider);
    final schedules = ref.read(scheduleListProvider);
    final activeProfile = ref.read(activeProfileProvider);

    final orgName = userSetup.organizationName.isNotEmpty ? userSetup.organizationName : 'Schedly';
    final term = activeProfile?.name ?? 'Current Timetable';

    final buffer = StringBuffer();
    buffer.writeln('📅 $term');
    buffer.writeln('👤 ${auth.userName}');
    buffer.writeln('🏫 $orgName');
    buffer.writeln('═' * 32);
    buffer.writeln();

    const weekdays = [
      (1, 'MONDAY'),
      (2, 'TUESDAY'),
      (3, 'WEDNESDAY'),
      (4, 'THURSDAY'),
      (5, 'FRIDAY'),
      (6, 'SATURDAY'),
      (7, 'SUNDAY'),
    ];

    int count = 0;
    for (final day in weekdays) {
      final daySchedules = schedules
          .where((s) => s.isActive && s.daysOfWeek.contains(day.$1))
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));

      if (daySchedules.isNotEmpty) {
        buffer.writeln('📌 ${day.$2}:');
        for (final s in daySchedules) {
          count++;
          final start12 = TimeUtils.formatTo12Hour(s.startTime);
          final end12 = TimeUtils.formatTo12Hour(s.endTime);
          final loc = s.location != null && s.location!.trim().isNotEmpty ? ' • ${s.location!.trim()}' : '';
          buffer.writeln('  • $start12 - $end12 | ${s.title}$loc');
        }
        buffer.writeln();
      }
    }

    if (count == 0) {
      buffer.writeln('No active schedules found.');
      buffer.writeln();
    }

    buffer.writeln('— Generated via Schedly Timetable');

    await Share.share(
      buffer.toString(),
      subject: 'My Timetable - ${auth.userName}',
    );
  }

  void _exportAsCsv() async {
    final auth = ref.read(authProvider);
    final schedules = ref.read(scheduleListProvider);

    final buffer = StringBuffer();
    buffer.writeln('Title,Category,Days,Start Time,End Time,Spans Next Day,Location,Notes');

    for (final s in schedules) {
      final cleanTitle = s.title.replaceAll('"', '""');
      final cleanCat = s.category.name;
      final cleanDays = _formatDays(s.daysOfWeek).replaceAll('"', '""');
      final start12 = TimeUtils.formatTo12Hour(s.startTime);
      final end12 = TimeUtils.formatTo12Hour(s.endTime);
      final spans = s.spansNextDay ? 'Yes' : 'No';
      final cleanLoc = (s.location ?? '').replaceAll('"', '""');
      final cleanNotes = (s.notes ?? '').replaceAll('"', '""');

      buffer.writeln('"$cleanTitle","$cleanCat","$cleanDays","$start12","$end12","$spans","$cleanLoc","$cleanNotes"');
    }

    await Share.share(
      buffer.toString(),
      subject: 'Schedly Timetable Export (CSV) - ${auth.userName}',
    );
  }

  void _exportAsJson() async {
    final auth = ref.read(authProvider);
    final userSetup = ref.read(userSetupProvider);
    final schedules = ref.read(scheduleListProvider);
    final activeProfile = ref.read(activeProfileProvider);

    final detectedTerm = AcademicTermDetector.computeCurrentTerm(
      role: userSetup.role,
      orgName: userSetup.organizationName,
    );

    final exportMap = {
      'app': 'Schedly',
      'version': '1.0.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'user': {
        'name': auth.userName,
        'email': auth.userEmail,
        'role': userSetup.role,
        'school': userSetup.organizationName,
        'term': activeProfile?.name.contains('AY') == true
            ? activeProfile!.name
            : detectedTerm,
      },
      'totalSchedules': schedules.length,
      'schedules': schedules.map((e) => e.toJson()).toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(exportMap);

    await Share.share(
      jsonString,
      subject: 'Schedly Raw Backup (JSON) - ${auth.userName}',
    );
  }

  void _onSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFF2563EB), size: 24),
            SizedBox(width: 10),
            Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        content: const Text('Are you sure you want to sign out of your Reminda account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Sign Out'),
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

  void _onDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 26),
            SizedBox(width: 10),
            Text('Delete Account', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFEF4444))),
          ],
        ),
        content: const Text(
          'This action is irreversible. All your schedules, profiles, and cloud backup data will be permanently deleted from Reminda.',
        ),
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
            child: const Text('Permanently Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isDeleting = true);
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          try {
            await appFirestore.collection('users').doc(user.uid).delete();
          } catch (_) {}
          try {
            await user.delete();
          } catch (_) {}
        }
        await ref.read(scheduleListProvider.notifier).clearAll();
        await ref.read(authProvider.notifier).logout();
        await ref.read(userSetupProvider.notifier).reset();
        ref.read(scheduleListProvider.notifier).clearLocalMemory();
        ref.read(profileListProvider.notifier).clearLocalMemory();

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isDeleting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete account: $e'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    }
  }

  void _editNameDialog() async {
    final auth = ref.read(authProvider);
    final controller = TextEditingController(text: auth.userName);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Display Name', style: TextStyle(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Full Name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && mounted) {
      await ref.read(authProvider.notifier).updateDisplayName(newName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = ref.watch(authProvider);
    final userSetup = ref.watch(userSetupProvider);
    final activeProfile = ref.watch(activeProfileProvider);

    final schoolName = userSetup.organizationName.isNotEmpty
        ? userSetup.organizationName
        : 'Cor Jesu College, Inc. (CJC)';

    // Dynamic Intelligent Academic Calendar & Term Detection Algorithm
    final detectedTerm = AcademicTermDetector.computeCurrentTerm(
      role: userSetup.role,
      orgName: schoolName,
    );

    final termName = activeProfile != null && activeProfile.name.contains('AY')
        ? activeProfile.name
        : detectedTerm;

    // Lookup Institution Item for Official Logo
    final institutionItem = InstitutionItem.findByDetails(
      name: schoolName,
      role: userSetup.role,
    );

    final sectionTitle = userSetup.role == 'duty'
        ? 'Clinical Duty / Hospital'
        : (userSetup.role == 'work' ? 'Workplace' : 'School');

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : Colors.white,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Center(
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 17,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
          ),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? AppColors.backgroundDark : Colors.white,
      ),
      body: _isDeleting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // Big Center Avatar (Tappable to change photo)
                  Center(
                    child: GestureDetector(
                      onTap: _changeProfilePhoto,
                      behavior: HitTestBehavior.opaque,
                      child: Stack(
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF2563EB),
                                width: 2.5,
                              ),
                            ),
                            child: ClipOval(
                              child: _buildAvatarImage(auth.userPhotoUrl, auth.userName),
                            ),
                          ),
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 13,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Center Name & Email
                  Center(
                    child: Column(
                      children: [
                        Text(
                          auth.userName,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          auth.isGuest ? 'guest@reminda.app' : auth.userEmail,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Display Name Row (Clickable to Edit)
                  InkWell(
                    onTap: _editNameDialog,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              auth.userName,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your name and photo appear on schedules you share and sync across your devices.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Section Header (School / Workplace / Clinical Duty)
                  Text(
                    sectionTitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // School / Institution Card matching mockup with genuine Logo & Auto Term
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      children: [
                        // School Name Row with Genuine Logo
                        Row(
                          children: [
                            InstitutionLogo(
                              item: institutionItem,
                              size: 40,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                schoolName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          ],
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Divider(
                            height: 1,
                            thickness: 1,
                            color: isDark ? AppColors.borderDark : const Color(0xFFF1F5F9),
                          ),
                        ),

                        // Term Row with Dynamic Detected Term
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Term',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              termName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 6),
                  Text(
                    'Your school comes from the schedule currently active on this device.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Your Data Section Header
                  Text(
                    'Your Data',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Export My Data Action
                  InkWell(
                    onTap: () => _showExportOptionsSheet(context),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.description_outlined,
                            color: Color(0xFF2563EB),
                            size: 24,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'Export My Data',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),
                  Text(
                    'Export your schedule as formatted text, Excel CSV, or raw JSON backup.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Sign Out Item
                  InkWell(
                    onTap: _onSignOut,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.logout_rounded,
                            color: Color(0xFF2563EB),
                            size: 22,
                          ),
                          const SizedBox(width: 14),
                          Text(
                            'Sign Out',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: isDark ? AppColors.borderDark : const Color(0xFFF1F5F9),
                    ),
                  ),

                  // Delete Account Item (Destructive Red)
                  InkWell(
                    onTap: _onDeleteAccount,
                    borderRadius: BorderRadius.circular(14),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            color: Color(0xFFEF4444),
                            size: 22,
                          ),
                          SizedBox(width: 14),
                          Text(
                            'Delete Account',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildInitialsAvatar(String name) {
    return Container(
      color: const Color(0xFF2563EB),
      child: Center(
        child: Text(
          _getInitials(name),
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
