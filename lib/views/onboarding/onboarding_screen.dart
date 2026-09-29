import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/page_transitions.dart';
import '../../providers/auth_provider.dart';
import 'login_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  void _onNext() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutCubic,
      );
    } else {
      _goToLogin();
    }
  }

  void _onSkip() async {
    await ref.read(authProvider.notifier).completeOnboarding();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        SmoothSlideFadeRoute(page: const LoginScreen()),
      );
    }
  }

  void _goToLogin() async {
    await ref.read(authProvider.notifier).completeOnboarding();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        SmoothSlideFadeRoute(page: const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      body: Stack(
        children: [
          // Background Ambient Blur Blobs (Matching Reference Design)
          if (!isDark) ...[
            Positioned(
              top: 160,
              right: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEDE9FE).withValues(alpha: 0.6),
                ),
              ),
            ),
            Positioned(
              top: 220,
              right: 60,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFBAE6FD).withValues(alpha: 0.7),
                ),
              ),
            ),
            Positioned(
              bottom: 260,
              right: 40,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEDE9FE).withValues(alpha: 0.8),
                ),
              ),
            ),
          ],

          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  children: [
                    // 3-Step Swipeable Carousel
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        physics: const BouncingScrollPhysics(),
                        onPageChanged: (index) {
                          setState(() => _currentPage = index);
                        },
                        children: [
                          // Slide 1: Scan & Import
                          _buildSlide(
                            slideIndex: 0,
                            titlePrefix: 'Your Schedule,\n',
                            titleAccent: 'Smarter.',
                            subtitle:
                                'Import, organize, and get reminded\nbefore every class, shift, or duty.',
                            heroWidget: _buildMascotHero(isDark, _currentPage == 0),
                            cards: [
                              _buildModernCard(
                                icon: Icons.calendar_month_rounded,
                                title: 'Scan & Import',
                                subtitle: 'Upload a screenshot of your schedule',
                                isDark: isDark,
                              ),
                              _buildModernCard(
                                icon: Icons.notifications_rounded,
                                title: 'Get Reminded',
                                subtitle: 'Receive smart reminders on time',
                                isDark: isDark,
                              ),
                              _buildModernCard(
                                icon: Icons.cloud_done_rounded,
                                title: 'Stay Organized',
                                subtitle: 'All your schedules in one place',
                                isDark: isDark,
                              ),
                            ],
                            isDark: isDark,
                          ),

                          // Slide 2: Let's set up your preferences
                          _buildSlide(
                            slideIndex: 1,
                            titlePrefix: 'Let’s set up\n',
                            titleAccent: 'your preferences.',
                            subtitle:
                                'Tell us a bit about your schedule\nso we can personalize your experience.',
                            heroWidget: _buildMascotThinkingHero(isDark, _currentPage == 1),
                            cards: [
                              _buildModernCard(
                                icon: Icons.calendar_month_rounded,
                                title: 'Class Schedule',
                                subtitle: 'Add your classes and\nset your timetable',
                                isDark: isDark,
                              ),
                              _buildModernCard(
                                icon: Icons.access_time_rounded,
                                title: 'Availability',
                                subtitle: 'Set your free time\nand busy hours',
                                isDark: isDark,
                              ),
                              _buildModernCard(
                                icon: Icons.notifications_none_rounded,
                                title: 'Reminders',
                                subtitle: 'Choose how and when\nyou want to be reminded',
                                isDark: isDark,
                              ),
                            ],
                            isDark: isDark,
                          ),

                          // Slide 3: Multi-Schedule Profiles & Sync
                          _buildSlide(
                            slideIndex: 2,
                            titlePrefix: 'All Your Schedules,\n',
                            titleAccent: 'One Single App.',
                            subtitle:
                                'Separate your School, Part-Time Job,\nand Duty Rosters neatly in one dashboard.',
                            heroWidget: _buildThumbsUpHero(isDark, _currentPage == 2),
                            cards: [
                              _buildModernCard(
                                icon: Icons.school_rounded,
                                title: 'School & Classes',
                                subtitle: 'Room numbers, profs, and breaks',
                                isDark: isDark,
                              ),
                              _buildModernCard(
                                icon: Icons.work_rounded,
                                title: 'Job & Work Shifts',
                                subtitle: 'Morning, evening, & weekend shifts',
                                isDark: isDark,
                              ),
                              _buildModernCard(
                                icon: Icons.shield_rounded,
                                title: 'Duty Rosters',
                                subtitle: 'Overnight span & shift rotations',
                                isDark: isDark,
                              ),
                            ],
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),

                    // Bottom Controls (Dots + Next/Get Started + Skip)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24.0, 4.0, 24.0, 10.0),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                      // Animated 3-Dots Page Indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (index) {
                          final isSelected = _currentPage == index;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: isSelected ? 22 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF2563EB)
                                  : (isDark
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFCBD5E1)),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                                        blurRadius: 6,
                                      ),
                                    ]
                                  : null,
                            ),
                          );
                        }),
                      ),

                      const SizedBox(height: 16),

                      // Primary Button with Smooth Text Morph ("Next" vs "Get Started")
                      Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _onNext,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            transitionBuilder: (child, anim) => FadeTransition(
                              opacity: anim,
                              child: ScaleTransition(scale: anim, child: child),
                            ),
                            child: Text(
                              _currentPage == 2 ? 'Get Started' : 'Next',
                              key: ValueKey<int>(_currentPage == 2 ? 1 : 0),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Outlined "Skip" Button
                      Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: OutlinedButton(
                          onPressed: _onSkip,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Skip',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Footer: "Already have an account? Log in"
                      GestureDetector(
                        onTap: _goToLogin,
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : const Color(0xFF64748B),
                            ),
                            children: const [
                              TextSpan(text: 'Already have an account? '),
                              TextSpan(
                                text: 'Log in',
                                style: TextStyle(
                                  color: Color(0xFF2563EB),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
],
),
);
}

  Widget _buildSlide({
    required int slideIndex,
    required String titlePrefix,
    required String titleAccent,
    required String subtitle,
    required Widget heroWidget,
    required List<Widget> cards,
    required bool isDark,
  }) {
    final bool isCurrent = _currentPage == slideIndex;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          const SizedBox(height: 10),

          // Header Title with Dynamic Entrance
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: isDark ? AppColors.textPrimaryDark : const Color(0xFF0F172A),
                letterSpacing: -0.8,
                height: 1.15,
              ),
              children: [
                TextSpan(text: titlePrefix),
                TextSpan(
                  text: titleAccent,
                  style: const TextStyle(color: Color(0xFF2563EB)),
                ),
              ],
            ),
          )
              .animate(target: isCurrent ? 1 : 0)
              .fadeIn(duration: 400.ms)
              .slideY(begin: -0.08, end: 0, curve: Curves.easeOutCubic),

          const SizedBox(height: 10),

          // Subtitle with Dynamic Entrance
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
              height: 1.35,
            ),
          )
              .animate(target: isCurrent ? 1 : 0)
              .fadeIn(delay: 80.ms, duration: 400.ms)
              .slideY(begin: -0.06, end: 0, curve: Curves.easeOutCubic),

          const SizedBox(height: 12),

          // Center Stage (Responsive LayoutBuilder - Never Overflows!)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double availableHeight = constraints.maxHeight;
                final double stageHeight = availableHeight.clamp(220.0, 300.0);

                return Center(
                  child: SizedBox(
                    height: stageHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Left Hero Area
                        heroWidget,

                        // Right 3 Modern Cards (Staggered Cascade Animation)
                        Positioned(
                          left: 165,
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(cards.length, (i) {
                              return cards[i]
                                  .animate(target: isCurrent ? 1 : 0)
                                  .fadeIn(delay: (80 + (i * 80)).ms, duration: 400.ms)
                                  .slideX(begin: 0.15, end: 0, curve: Curves.easeOutCubic);
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 6),
        ],
      ),
    ),
  ),
);
}

  // Slide 1 Hero: Mascot
  Widget _buildMascotHero(bool isDark, bool isCurrent) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -45,
          top: 20,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [const Color(0xFFE2EDFF), const Color(0xFFEFF6FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        Positioned(
          left: -25,
          top: -10,
          bottom: -10,
          width: 210,
          child: Transform.scale(
            scale: 1.12,
            alignment: Alignment.centerLeft,
            child: Image.asset(
              'assets/images/Friendly 3D Hoodie Mascot with Smartphone.png',
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              errorBuilder: (context, error, stackTrace) => Image.asset(
                'assets/images/mascot.png',
                fit: BoxFit.contain,
              ),
            ),
          )
              .animate(target: isCurrent ? 1 : 0)
              .fadeIn(duration: 450.ms)
              .scale(
                begin: const Offset(0.9, 0.9),
                end: const Offset(1.0, 1.0),
                duration: 550.ms,
                curve: Curves.easeOutBack,
              ),
        ),
      ],
    );
  }

  // Slide 2 Hero: Mascot in Thinking Pose
  Widget _buildMascotThinkingHero(bool isDark, bool isCurrent) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -45,
          top: 20,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [const Color(0xFFE2EDFF), const Color(0xFFEFF6FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        Positioned(
          left: -25,
          top: -10,
          bottom: -10,
          width: 210,
          child: Transform.scale(
            scale: 1.12,
            alignment: Alignment.centerLeft,
            child: Image.asset(
              'assets/images/Thoughtful 3D Figure with Smartphone.png',
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              errorBuilder: (context, error, stackTrace) => Image.asset(
                'assets/images/mascot_thinking.png',
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
                errorBuilder: (context, error, stackTrace) => Image.asset(
                  'assets/images/Friendly 3D Hoodie Mascot with Smartphone.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          )
              .animate(target: isCurrent ? 1 : 0)
              .fadeIn(duration: 450.ms)
              .scale(
                begin: const Offset(0.9, 0.9),
                end: const Offset(1.0, 1.0),
                duration: 550.ms,
                curve: Curves.easeOutBack,
              ),
        ),
      ],
    );
  }

  // Slide 3 Hero: Friendly Smartphone Thumbs-Up Mascot
  Widget _buildThumbsUpHero(bool isDark, bool isCurrent) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -45,
          top: 20,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [const Color(0xFFE2EDFF), const Color(0xFFEFF6FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        Positioned(
          left: -25,
          top: -10,
          bottom: -10,
          width: 210,
          child: Transform.scale(
            scale: 1.12,
            alignment: Alignment.centerLeft,
            child: Image.asset(
              'assets/images/Friendly Smartphone Thumbs-Up Mascot.png',
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              errorBuilder: (context, error, stackTrace) => Image.asset(
                'assets/images/mascot_thumbsup.png',
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
                errorBuilder: (context, error, stackTrace) => Image.asset(
                  'assets/images/mascot.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          )
              .animate(target: isCurrent ? 1 : 0)
              .fadeIn(duration: 450.ms)
              .scale(
                begin: const Offset(0.9, 0.9),
                end: const Offset(1.0, 1.0),
                duration: 550.ms,
                curve: Curves.easeOutBack,
              ),
        ),
      ],
    );
  }

  Widget _buildModernCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.transparent,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : const Color(0xFFE0EDFF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF2563EB),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.textPrimaryDark : const Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
