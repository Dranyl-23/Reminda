import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/database/institution_sync_service.dart';
import '../../core/utils/page_transitions.dart';
import '../../models/alarm_tone.dart';
import '../../models/institution_directory.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sound_settings_provider.dart';
import '../../providers/user_setup_provider.dart';
import '../navigation/main_navigation_shell.dart';
import 'widgets/institution_logo.dart';

class WorkspaceSetupScreen extends ConsumerStatefulWidget {
  const WorkspaceSetupScreen({super.key});

  @override
  ConsumerState<WorkspaceSetupScreen> createState() => _WorkspaceSetupScreenState();
}

class _WorkspaceSetupScreenState extends ConsumerState<WorkspaceSetupScreen> {
  int _currentStep = 1;
  bool _isLoading = false;
  final PageController _pageController = PageController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customOrgController = TextEditingController();

  String _searchQuery = '';

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    _customOrgController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_isLoading) return;

    if (_currentStep == 2) {
      final setup = ref.read(userSetupProvider);
      if (setup.organizationName.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select or add your institution / workplace.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFFDC2626),
          ),
        );
        return;
      }
    }

    if (_currentStep < 3) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishSetup();
    }
  }

  void _prevStep() {
    if (_isLoading) return;
    if (_currentStep > 1) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finishSetup() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      await ref.read(userSetupProvider.notifier).completeSetup(ref);
    } catch (_) {}

    if (!mounted) return;
    setState(() => _isLoading = false);

    Navigator.pushAndRemoveUntil(
      context,
      SmoothSlideFadeRoute(page: const MainNavigationShell()),
      (route) => false,
    );
  }

  void _showAddCustomOrgDialog(bool isDark) {
    _customOrgController.clear();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Add Custom Workplace / School',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          content: TextField(
            controller: _customOrgController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter name (e.g. My Clinic, ABC Corp)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = _customOrgController.text.trim();
                if (name.isNotEmpty) {
                  ref.read(userSetupProvider.notifier).updateOrganization(
                        name: name,
                        shortName: name,
                        colorHex: '#2563EB',
                      );
                  Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
              child: const Text('Select'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final setup = ref.watch(userSetupProvider);
    final auth = ref.watch(authProvider);

    final rawName = auth.userName.trim();
    final firstName = rawName.isEmpty || rawName == 'Guest User'
        ? (auth.isGuest ? 'there' : 'User')
        : rawName.split(' ').first;
    final isGuest = auth.isGuest;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
        elevation: 0,
        leading: _currentStep > 1
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _prevStep,
              )
            : null,
        title: Text(
          'Step $_currentStep of 3',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _finishSetup,
            child: const Text(
              'Skip',
              style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Step Progress Indicator Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [1, 2, 3].map((step) {
                  final isDone = _currentStep >= step;
                  return Expanded(
                    child: Container(
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: isDone ? const Color(0xFF2563EB) : (isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1Role(isDark, firstName, isGuest, setup),
                  _buildStep2Institution(isDark, setup),
                  _buildStep3Alarms(isDark, setup),
                ],
              ),
            ),

            // Bottom Action Button
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Container(
                width: double.infinity,
                height: 52,
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
                child: ElevatedButton(
                  onPressed: _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          _currentStep == 3 ? 'Complete Setup & Launch Reminda' : 'Continue',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= STEP 1: ROLE SELECTION =================
  Widget _buildStep1Role(bool isDark, String firstName, bool isGuest, UserSetupState setup) {
    final roles = [
      {
        'key': 'school',
        'title': 'Student / University',
        'desc': 'Class schedules, lab courses, and exam timetables',
        'icon': Icons.school_rounded,
        'color': const Color(0xFF2563EB),
      },
      {
        'key': 'work',
        'title': 'Private Workplace / Retail',
        'desc': 'Shifts at Jollibee, McDonald\'s, SM, Gaisano, BPO & offices',
        'icon': Icons.work_rounded,
        'color': const Color(0xFFF59E0B),
      },
      {
        'key': 'duty',
        'title': 'Healthcare & Duty Roster',
        'desc': 'Hospital clinical duty, nursing rotations & on-call shifts',
        'icon': Icons.local_hospital_rounded,
        'color': const Color(0xFF10B981),
      },
      {
        'key': 'gov',
        'title': 'Government Sector',
        'desc': 'DepEd, City Hall, Provincial Capitol & public service',
        'icon': Icons.account_balance_rounded,
        'color': const Color(0xFF8B5CF6),
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Welcome, $firstName! ',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              if (isGuest) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF64748B).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF94A3B8).withValues(alpha: 0.5)),
                  ),
                  child: const Text(
                    ' Guest',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isGuest
                ? 'Let\'s set up your workspace — you can create an account anytime later'
                : 'What will you mainly use Reminda for?',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 20),


          ...roles.map((r) {
            final key = r['key'] as String;
            final isSelected = setup.role == key;
            final color = r['color'] as Color;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => ref.read(userSetupProvider.notifier).updateRole(key),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.08)
                        : (isDark ? AppColors.surfaceDark : Colors.white),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? color
                          : (isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(r['icon'] as IconData, color: color, size: 26),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r['title'] as String,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              r['desc'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: isSelected ? color : const Color(0xFFCBD5E1),
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ================= STEP 2: INSTITUTION & DIRECTORY =================
  Widget _buildStep2Institution(bool isDark, UserSetupState setup) {
    // Subscribe reactively to cloud institution updates so new schools appear live
    ref.watch(cloudInstitutionsRevisionProvider);
    final regions = PhRegion.forCountry(setup.countryCode);
    final cities  = setup.regionCode.isNotEmpty ? PhCity.forRegion(setup.regionCode) : <PhCity>[];
    final filtered = setup.regionCode.isNotEmpty
        ? InstitutionItem.filter(
            category:   setup.role,
            regionCode: setup.regionCode,
            city:       setup.city,
            query:      _searchQuery,
          )
        : <InstitutionItem>[];

    InputDecoration dropdownDecoration({
      required String hint,
      required IconData icon,
      required Color iconColor,
    }) {
      return InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 13.5,
          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
        ),
        prefixIcon: Icon(icon, color: iconColor, size: 20),
        filled: true,
        fillColor: isDark ? AppColors.surfaceDark : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.8),
        ),
      );
    }

    Widget sectionLabel(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
        ),
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Location & Institution ',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Find your school, company branch, or hospital',
            style: TextStyle(
              fontSize: 13.5,
              color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 18),

          // ── COUNTRY ──────────────────────────────────
          sectionLabel('COUNTRY'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: PhCountry.all.map((country) {
                final isSelected = setup.countryCode == country.code;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => ref.read(userSetupProvider.notifier).updateCountry(country.code),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF2563EB)
                            : (isDark ? AppColors.surfaceDark : Colors.white),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF2563EB)
                              : (isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isSelected
                                ? const Color(0xFF2563EB).withValues(alpha: 0.3)
                                : Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(country.flag, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Text(
                            country.name,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.white70 : const Color(0xFF334155)),
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 12,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          // ── REGION DROPDOWN ──────────────────────────────────
          sectionLabel('REGION'),
          DropdownButtonFormField<String>(
            key: ValueKey('region_${setup.regionCode}'),
            initialValue: regions.any((r) => r.code == setup.regionCode) ? setup.regionCode : null,
            isExpanded: true,
            dropdownColor: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
            decoration: dropdownDecoration(
              hint: 'Select Region',
              icon: Icons.map_rounded,
              iconColor: const Color(0xFF7C3AED),
            ),
            items: regions.map((region) {
              return DropdownMenuItem(
                value: region.code,
                child: Text(
                  region.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                ref.read(userSetupProvider.notifier).updateRegion(val);
              }
            },
          ),

          const SizedBox(height: 14),

          // ── CITY DROPDOWN ──────────────────────────────────
          if (cities.isNotEmpty) ...[
            sectionLabel('CITY / MUNICIPALITY'),
            DropdownButtonFormField<String>(
              key: ValueKey('city_${setup.regionCode}_${setup.city}'),
              initialValue: setup.city.isEmpty ? '' : (cities.any((c) => c.name == setup.city) ? setup.city : ''),
              isExpanded: true,
              dropdownColor: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              decoration: dropdownDecoration(
                hint: 'Select City / Municipality',
                icon: Icons.location_city_rounded,
                iconColor: const Color(0xFF0D9488),
              ),
              items: [
                DropdownMenuItem(
                  value: '',
                  child: Text(
                    '  All Cities / Municipalities',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                ...cities.map((city) {
                  return DropdownMenuItem(
                    value: city.name,
                    child: Text(
                      city.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  );
                }),
              ],
              onChanged: (val) {
                if (val != null) {
                  ref.read(userSetupProvider.notifier).updateCity(val);
                }
              },
            ),
            const SizedBox(height: 14),
          ],

          // ── SEARCH ──────────────────────────────────
          if (setup.regionCode.isNotEmpty) ...[
            const SizedBox(height: 18),
            sectionLabel('SEARCH INSTITUTION'),
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                decoration: InputDecoration(
                  hintText: 'Search school, mall, hospital...',
                  hintStyle: TextStyle(fontSize: 13.5, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF2563EB)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── INSTITUTION LIST ─────────────────────
            if (filtered.isNotEmpty)
              ...filtered.map((item) {
                final isSelected = setup.organizationName == item.name;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () {
                      ref.read(userSetupProvider.notifier).updateOrganization(
                            name: item.name,
                            shortName: item.shortName,
                            colorHex: '#${item.themeColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                          );
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? item.themeColor.withValues(alpha: isDark ? 0.12 : 0.07)
                            : (isDark ? AppColors.surfaceDark : Colors.white),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? item.themeColor
                              : (isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
                          width: isSelected ? 2.0 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isSelected
                                ? item.themeColor.withValues(alpha: isDark ? 0.25 : 0.12)
                                : Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
                            blurRadius: isSelected ? 10 : 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Official Logo / Monogram Emblem Avatar
                          InstitutionLogo(item: item, size: 44),
                          const SizedBox(width: 14),
                          // Info Column
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 3,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: item.themeColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item.shortName,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: item.themeColor,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '•  ${item.city}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Selected Check / Radio Icon
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? item.themeColor : Colors.transparent,
                              border: Border.all(
                                color: isSelected ? item.themeColor : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                                width: isSelected ? 0 : 1.6,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              })
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.search_off_rounded, size: 40,
                          color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                      const SizedBox(height: 8),
                      Text(
                        'No institutions found matching your search.\nYou can add your custom organization below.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.textSecondaryDark : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],

          if (setup.regionCode.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Column(
                  children: [
                    const Text(' ', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 10),
                    Text(
                      'Select your Region above\nto see institutions near you',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppColors.textSecondaryDark : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── CUSTOM / UNLISTED WORKPLACE OR SCHOOL ────────────────────
          const SizedBox(height: 6),
          InkWell(
            onTap: () => _showAddCustomOrgDialog(isDark),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add_business_rounded, color: Color(0xFF2563EB), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Custom Workplace or School',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Can't find yours in the list? Tap to add manually",
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF2563EB), size: 16),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // ================= STEP 3: ALARM & SOUND SETUP =================
  Widget _buildStep3Alarms(bool isDark, UserSetupState setup) {
    final soundNotifier = ref.read(soundSettingsProvider.notifier);
    final soundState = ref.watch(soundSettingsProvider);

    final leadOptions = [5, 10, 15, 30, 60];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Smart Alarm Preferences ',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Personalize your reminder lead time and alarm ringtone',
            style: TextStyle(
              fontSize: 13.5,
              color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 20),

          // Reminder Lead Time
          Text(
            'REMINDER LEAD TIME',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: leadOptions.map((mins) {
                final isSelected = setup.reminderLeadMinutes == mins;
                final label = mins == 60 ? '1 hour before' : '$mins mins before';

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (_) => ref.read(userSetupProvider.notifier).updateReminderLead(mins),
                    selectedColor: const Color(0xFF2563EB),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 12,
                    ),
                    backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF2563EB) : (isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 24),

          // Ringtone Selection
          Text(
            'DEFAULT ALARM TONE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 10),

          ...AlarmTone.presets.map((tone) {
            final isSelected = setup.selectedToneId == tone.id;
            final isPlaying = soundState.playingToneId == tone.id;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () {
                  ref.read(userSetupProvider.notifier).updateTone(tone.id);
                  soundNotifier.playPreview(tone.id);
                },
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF2563EB).withValues(alpha: 0.08)
                        : (isDark ? AppColors.surfaceDark : Colors.white),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF2563EB)
                          : (isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
                      width: isSelected ? 1.6 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: tone.color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(tone.icon, color: tone.color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tone.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              tone.description,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => soundNotifier.playPreview(tone.id),
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isPlaying ? const Color(0xFF2563EB) : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPlaying ? Icons.volume_up_rounded : Icons.play_arrow_rounded,
                            size: 16,
                            color: isPlaying ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF475569)),
                          ),
                        ),
                      ),
                      Icon(
                        isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
