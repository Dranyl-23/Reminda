import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/page_transitions.dart';
import '../../models/schedule_profile.dart';
import '../../providers/profile_provider.dart';
import '../../providers/schedule_provider.dart';
import 'profile_schedule_timetable_view.dart';

class ScheduleProfilesView extends ConsumerWidget {
  const ScheduleProfilesView({super.key});

  void _showCreateProfileDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateProfileSheet(
        onCreated: (newProfile, profileName) {
          ref.read(profileListProvider.notifier).addProfile(newProfile);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Profile "$profileName" created successfully!'),
                backgroundColor: const Color(0xFF10B981),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  void _confirmDeleteProfile(BuildContext context, WidgetRef ref, ScheduleProfile profile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profiles = ref.read(profileListProvider);

    if (profiles.length <= 1) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Color(0xFFF59E0B)),
              SizedBox(width: 8),
              Text('Cannot Delete', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            ],
          ),
          content: const Text(
            'You must keep at least one active schedule profile in Reminda.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF2563EB))),
            ),
          ],
        ),
      );
      return;
    }

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
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Delete Profile & Schedules?',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${profile.name}"? All schedules and reminders under this profile will be permanently wiped out.',
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
            onPressed: () async {
              Navigator.pop(ctx);
              // Wipe out all schedule entries under this profile
              await ref.read(scheduleListProvider.notifier).deleteSchedulesForProfile(profile.id);
              // Delete the profile itself
              await ref.read(profileListProvider.notifier).deleteProfile(profile.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Permanently deleted "${profile.name}" and all its schedules'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: const Color(0xFFDC2626),
                  ),
                );
              }
            },
            child: const Text('Delete Profile', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, WidgetRef ref, ScheduleProfile profile) {
    showDialog(
      context: context,
      builder: (ctx) => _EditProfileDialog(
        profile: profile,
        onSaved: (newName) async {
          final updated = profile.copyWith(name: newName, updatedAt: DateTime.now());
          await ref.read(profileListProvider.notifier).addProfile(updated);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final profiles = ref.watch(profileListProvider);
    final allSchedules = ref.watch(scheduleListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Schedules'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'New Schedule Profile',
            onPressed: () => _showCreateProfileDialog(context, ref),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: profiles.length + 1, // +1 for the Add New Profile button at the end
        itemBuilder: (context, index) {
          if (index == profiles.length) {
            // End Action Card: Add New Profile
            return Container(
              margin: const EdgeInsets.only(top: 8),
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => _showCreateProfileDialog(context, ref),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text(
                  'New Schedule Profile',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: isDark ? AppColors.borderDark : const Color(0xFFCBD5E1),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            );
          }

          final profile = profiles[index];
          final isSelected = profile.isActive || profiles.length == 1;
          final validProfileIds = profiles.map((p) => p.id).toSet();
          final count = allSchedules.where((s) {
            if (s.profileId == profile.id) return true;
            final pid = s.profileId?.trim() ?? '';
            final isOrphanedOrUnassigned = pid.isEmpty || !validProfileIds.contains(pid);
            return isSelected && isOrphanedOrUnassigned;
          }).length;
          final scheduleCountText = count == 0 ? 'No schedules' : '$count schedule${count > 1 ? 's' : ''}';

          return Dismissible(
            key: Key(profile.id),
            direction: DismissDirection.endToStart,
            confirmDismiss: (direction) async {
              if (profiles.length <= 1) {
                _confirmDeleteProfile(context, ref, profile);
                return false;
              }
              _confirmDeleteProfile(context, ref, profile);
              return false; // Handled by dialog confirmation
            },
            background: Container(
              margin: const EdgeInsets.only(bottom: 12),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Delete',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.delete_forever_rounded, color: Colors.white, size: 24),
                ],
              ),
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF2563EB)
                      : (isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: profile.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(profile.icon, color: profile.color, size: 22),
                ),
                title: Text(
                  profile.name,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                subtitle: Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (isSelected) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'ACTIVE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2563EB),
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                    Text(
                      '$scheduleCountText • Updated ${DateFormat('MMM d, yyyy').format(profile.updatedAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Radio<bool>(
                      value: true,
                      // ignore: deprecated_member_use
                      groupValue: isSelected,
                      activeColor: const Color(0xFF2563EB),
                      // ignore: deprecated_member_use
                      onChanged: (_) {
                        ref.read(profileListProvider.notifier).setActive(profile.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Switched to "${profile.name}"')),
                        );
                      },
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: isDark ? AppColors.textSecondaryDark : const Color(0xFF94A3B8),
                        size: 20,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      color: isDark ? AppColors.surfaceDark : Colors.white,
                      onSelected: (val) {
                        if (val == 'edit') {
                          _showEditProfileDialog(context, ref, profile);
                        } else if (val == 'delete') {
                          _confirmDeleteProfile(context, ref, profile);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_rounded, size: 18, color: Color(0xFF2563EB)),
                              SizedBox(width: 10),
                              Text('Rename Profile', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                              SizedBox(width: 10),
                              Text('Delete Profile', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                onTap: () {
                  ref.read(profileListProvider.notifier).setActive(profile.id);
                  Navigator.push(
                    context,
                    SmoothSlideFadeRoute(
                      page: ProfileScheduleTimetableView(profile: profile),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CreateProfileSheet extends StatefulWidget {
  final void Function(ScheduleProfile newProfile, String profileName) onCreated;

  const _CreateProfileSheet({required this.onCreated});

  @override
  State<_CreateProfileSheet> createState() => _CreateProfileSheetState();
}

class _CreateProfileSheetState extends State<_CreateProfileSheet> {
  late final TextEditingController _nameController;
  String _selectedType = 'school';
  String _selectedHex = '#2563EB';

  static const _typeOptions = [
    {
      'type': 'school',
      'title': 'School / University',
      'desc': 'Class timetables, lectures & lab sessions',
      'icon': Icons.school_rounded,
      'color': Color(0xFF2563EB),
      'hex': '#2563EB',
    },
    {
      'type': 'work',
      'title': 'Work / Job Shift',
      'desc': 'Office hours, part-time shifts & meetings',
      'icon': Icons.work_rounded,
      'color': Color(0xFFF59E0B),
      'hex': '#F59E0B',
    },
    {
      'type': 'duty',
      'title': 'Duty Roster',
      'desc': 'Hospital shifts, clinical duties & rotations',
      'icon': Icons.badge_rounded,
      'color': Color(0xFF10B981),
      'hex': '#10B981',
    },
    {
      'type': 'custom',
      'title': 'Custom / Personal',
      'desc': 'Fitness, study routines & personal habits',
      'icon': Icons.star_rounded,
      'color': Color(0xFF8B5CF6),
      'hex': '#8B5CF6',
    },
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
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
                // Drag handle
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

                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'New Schedule Profile',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Create a separate timetable for school, duty, or work',
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

                const SizedBox(height: 18),

                // Profile Name Field
                Text(
                  'PROFILE NAME',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _nameController,
                    autofocus: false,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. 2nd Semester Classes, Hospital Duty',
                      hintStyle: TextStyle(
                        fontSize: 13.5,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                      prefixIcon: const Icon(
                        Icons.bookmark_outline_rounded,
                        size: 20,
                        color: Color(0xFF2563EB),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Profile Type Selection
                Text(
                  'SELECT PROFILE CATEGORY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 10),

                // 4 Option Cards
                ..._typeOptions.map((opt) {
                  final typeKey = opt['type'] as String;
                  final isSelected = _selectedType == typeKey;
                  final optColor = opt['color'] as Color;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedType = typeKey;
                          _selectedHex = opt['hex'] as String;
                        });
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? optColor.withValues(alpha: 0.09)
                              : (isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? optColor
                                : (isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
                            width: isSelected ? 1.6 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: optColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                opt['icon'] as IconData,
                                color: optColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    opt['title'] as String,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: isSelected
                                          ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                          : (isDark ? Colors.white70 : const Color(0xFF334155)),
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
                            Icon(
                              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              color: isSelected ? optColor : const Color(0xFFCBD5E1),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 18),

                // Create Button
                Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1D4ED8), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      final name = _nameController.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a profile name'),
                            backgroundColor: Color(0xFFDC2626),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }

                      final newProfile = ScheduleProfile(
                        name: name,
                        type: _selectedType,
                        colorHex: _selectedHex,
                        isActive: false,
                      );

                      Navigator.pop(context);
                      widget.onCreated(newProfile, name);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Create Profile',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
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
}

class _EditProfileDialog extends StatefulWidget {
  final ScheduleProfile profile;
  final ValueChanged<String> onSaved;

  const _EditProfileDialog({
    required this.profile,
    required this.onSaved,
  });

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Rename Profile',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
      ),
      content: TextField(
        controller: _nameController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Enter profile name',
          filled: true,
          fillColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
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
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            final newName = _nameController.text.trim();
            if (newName.isNotEmpty) {
              widget.onSaved(newName);
            }
            Navigator.pop(context);
          },
          child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}
