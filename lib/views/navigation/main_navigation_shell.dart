import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../calendar/calendar_view_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../profiles/schedule_profiles_view.dart';
import '../schedule/widgets/add_schedule_modal_dialog.dart';
import 'desktop_sidebar.dart';

final navigationIndexProvider = StateProvider<int>((ref) => 0);

class MainNavigationShell extends ConsumerWidget {
  const MainNavigationShell({super.key});

  void _showAddModal(BuildContext context) {
    AddScheduleModalDialog.show(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(navigationIndexProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.padding.bottom;
    final isDesktop = mediaQuery.size.width >= 850;

    final List<Widget> screens = [
      const HomeScreen(),
      const CalendarViewScreen(),
      const ScheduleProfilesView(),
      const ProfileScreen(),
    ];

    final desktopShortcuts = {
      const SingleActivator(LogicalKeyboardKey.keyN, control: true): () => _showAddModal(context),
      const SingleActivator(LogicalKeyboardKey.digit1, control: true): () => ref.read(navigationIndexProvider.notifier).state = 0,
      const SingleActivator(LogicalKeyboardKey.digit2, control: true): () => ref.read(navigationIndexProvider.notifier).state = 1,
      const SingleActivator(LogicalKeyboardKey.digit3, control: true): () => ref.read(navigationIndexProvider.notifier).state = 2,
      const SingleActivator(LogicalKeyboardKey.digit4, control: true): () => ref.read(navigationIndexProvider.notifier).state = 3,
    };

    if (isDesktop) {
      return CallbackShortcuts(
        bindings: desktopShortcuts,
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: Row(
              children: [
                DesktopSidebar(
                  currentIndex: currentIndex,
                  onIndexChanged: (idx) {
                    ref.read(navigationIndexProvider.notifier).state = idx;
                  },
                ),
                Expanded(
                  child: IndexedStack(
                    index: currentIndex,
                    children: screens,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: screens,
      ),
        bottomNavigationBar: Container(
        height: 68 + bottomPadding,
        padding: EdgeInsets.only(bottom: bottomPadding, top: 4),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.borderDark : const Color(0xFFF1F5F9),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Tab 0: Home
            _buildNavItem(
              context: context,
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
              label: 'Home',
              isSelected: currentIndex == 0,
              isDark: isDark,
              onTap: () => ref.read(navigationIndexProvider.notifier).state = 0,
            ),

            // Tab 1: Calendar / Timetable
            _buildNavItem(
              context: context,
              icon: Icons.calendar_today_outlined,
              selectedIcon: Icons.calendar_month_rounded,
              label: 'Calendar',
              isSelected: currentIndex == 1,
              isDark: isDark,
              onTap: () => ref.read(navigationIndexProvider.notifier).state = 1,
            ),

            // Center Action Button (+)
            GestureDetector(
              onTap: () => _showAddModal(context),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.38),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),

            // Tab 2: Schedules (My Schedule Sets)
            _buildNavItem(
              context: context,
              icon: Icons.layers_outlined,
              selectedIcon: Icons.layers_rounded,
              label: 'Schedules',
              isSelected: currentIndex == 2,
              isDark: isDark,
              onTap: () => ref.read(navigationIndexProvider.notifier).state = 2,
            ),

            // Tab 3: More (Account, Sync & App Preferences)
            _buildNavItem(
              context: context,
              icon: Icons.more_horiz_rounded,
              selectedIcon: Icons.more_horiz_rounded,
              label: 'More',
              isSelected: currentIndex == 3,
              isDark: isDark,
              onTap: () => ref.read(navigationIndexProvider.notifier).state = 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final activeColor = const Color(0xFF2563EB);
    final inactiveColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF2563EB).withValues(alpha: isDark ? 0.2 : 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                isSelected ? selectedIcon : icon,
                size: 22,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? activeColor : inactiveColor,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}