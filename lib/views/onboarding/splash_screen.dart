import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/page_transitions.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/user_setup_provider.dart';
import '../navigation/main_navigation_shell.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import 'workspace_setup_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;
  bool _isReady = false;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();

    // Subtle breathing/floating idle animation for the 3D logo
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(
        parent: _floatController,
        curve: Curves.easeInOutSine,
      ),
    );

    _startTransitionTimer();
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _startTransitionTimer() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await ref
            .read(userSetupProvider.notifier)
            .checkAndRestoreCloudSetup(user.uid)
            .timeout(const Duration(seconds: 8));
        if (!mounted) return;
        await ref
            .read(scheduleListProvider.notifier)
            .refreshFromCloud()
            .timeout(const Duration(seconds: 8));
        if (!mounted) return;
        ref.read(profileListProvider.notifier).refreshFromLocal();
      } catch (_) {}
    }

    if (mounted) {
      setState(() => _isReady = true);
    }

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    _navigateToNext();
  }

  void _navigateToNext() {
    if (!mounted || _isNavigating) return;
    _isNavigating = true;
    final user = FirebaseAuth.instance.currentUser;
    final auth = ref.read(authProvider);
    final isSetupDone = ref.read(userSetupProvider).isSetupCompleted;

    // Check direct Firebase Auth instance and local state
    final bool isLoggedIn = user != null || auth.isLoggedIn || auth.isGuest;

    final Widget targetScreen;
    if (isLoggedIn) {
      targetScreen = isSetupDone ? const MainNavigationShell() : const WorkspaceSetupScreen();
    } else if (auth.isOnboarded) {
      targetScreen = const LoginScreen();
    } else {
      targetScreen = const OnboardingScreen();
    }

    Navigator.pushReplacement(
      context,
      SmoothSlideFadeRoute(page: targetScreen),
    );
  }

  Widget _buildSparkle({required double size, required double opacity}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _isReady ? _navigateToNext : null,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF0038FF), // Royal Schedly Blue
                Color(0xFF1E1B4B), // Deep Navy
                Color(0xFF4C1D95), // Rich Purple Accent
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ambient Glowing Center Light
              Positioned(
                top: screenSize.height * 0.22,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF60A5FA).withValues(alpha: 0.18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.28),
                        blurRadius: 100,
                        spreadRadius: 30,
                      ),
                    ],
                  ),
                ),
              ),

              // Floating Stars/Particles Background Subtle Accents
              Positioned(
                top: screenSize.height * 0.12,
                left: 40,
                child: _buildSparkle(size: 6, opacity: 0.4),
              ),
              Positioned(
                top: screenSize.height * 0.28,
                right: 50,
                child: _buildSparkle(size: 8, opacity: 0.5),
              ),
              Positioned(
                top: screenSize.height * 0.45,
                left: 60,
                child: _buildSparkle(size: 5, opacity: 0.35),
              ),

              // Main Foreground Content
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 2),

                      // Prominent 3D Schedly Logo with Float & Scale Entrance
                      AnimatedBuilder(
                        animation: _floatAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, _floatAnimation.value),
                            child: child,
                          );
                        },
                        child: Image.asset(
                          'assets/images/Reminda - NoBG.png',
                          height: screenSize.height * 0.34,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.calendar_month_rounded,
                            size: 100,
                            color: Colors.white,
                          ),
                        )
                            .animate()
                            .fadeIn(duration: 600.ms, curve: Curves.easeOut)
                            .scale(
                              begin: const Offset(0.85, 0.85),
                              end: const Offset(1.0, 1.0),
                              duration: 700.ms,
                              curve: Curves.easeOutBack,
                            ),
                      ),

                      const SizedBox(height: 36),

                      // Tagline: "Scan. Parse. Schedule."
                      const Text(
                        'Scan. Parse. Schedule.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.6,
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 300.ms, duration: 550.ms)
                          .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),

                      const SizedBox(height: 6),

                      // Tagline: "Get Reminded." (Cyan Gradient Accent)
                      const Text(
                        'Get Reminded.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF38BDF8),
                          letterSpacing: -0.6,
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 450.ms, duration: 550.ms)
                          .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),

                      const SizedBox(height: 14),

                      // Subtitle
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Turn any schedule screenshot\ninto reminders you\'ll never miss.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.85),
                            height: 1.45,
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 600.ms, duration: 550.ms)
                          .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),

                      const Spacer(flex: 3),

                      // Touch Screen to Continue Prompt / Synchronization indicator
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Container(
                          key: ValueKey(_isReady),
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.28),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isReady ? Icons.touch_app_rounded : Icons.sync_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isReady ? 'Touch screen to continue' : 'Preparing your workspace...',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.95),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                          .animate(onPlay: (controller) => controller.repeat(reverse: true))
                          .fadeIn(delay: 700.ms, duration: 500.ms)
                          .scale(
                            begin: const Offset(0.96, 0.96),
                            end: const Offset(1.04, 1.04),
                            duration: 1100.ms,
                            curve: Curves.easeInOut,
                          ),

                      const SizedBox(height: 28),
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
}
