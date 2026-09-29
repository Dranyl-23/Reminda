import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/ai/schedule_parser_service.dart';
import '../../models/schedule_entry.dart';
import '../../providers/auth_provider.dart';
import '../../providers/schedule_provider.dart';
import 'review_scanned_schedules_view.dart';

class OcrProcessingView extends ConsumerStatefulWidget {
  final File? imageFile;
  final Uint8List imageBytes;
  final String mimeType;

  const OcrProcessingView({
    super.key,
    this.imageFile,
    required this.imageBytes,
    required this.mimeType,
  });

  @override
  ConsumerState<OcrProcessingView> createState() => _OcrProcessingViewState();
}

class _OcrProcessingViewState extends ConsumerState<OcrProcessingView>
    with SingleTickerProviderStateMixin {
  final ScheduleParserService _parserService = ScheduleParserService();

  int _currentStepIndex = 0; // 0..4
  late AnimationController _pulseController;
  Timer? _stepTimer;

  final List<String> _stepTitles = [
    'Image detected',
    'Extracting text (OCR)',
    'Reading schedule',
    'Creating events',
    'Almost done!',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _startStepSimulation();
    _startParsing();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _stepTimer?.cancel();
    super.dispose();
  }

  void _startStepSimulation() {
    _stepTimer = Timer.periodic(const Duration(milliseconds: 900), (timer) {
      if (_currentStepIndex < 3 && mounted) {
        setState(() {
          _currentStepIndex++;
        });
      }
    });
  }

  Future<void> _startParsing() async {
    final authState = ref.read(authProvider);
    final isGuest = authState.isGuest || !authState.isLoggedIn;

    final geminiKey = ref.read(geminiApiKeyProvider);
    final groqKey = ref.read(groqApiKeyProvider);
    final openRouterKey = ref.read(openRouterApiKeyProvider);
    final cfAccountId = ref.read(cloudflareAccountIdProvider);
    final cfApiToken = ref.read(cloudflareApiTokenProvider);
    final preferredEngine = isGuest ? 'offline' : ref.read(preferredAiEngineProvider);

    try {
      final List<ScheduleEntry> parsed = await _parserService.parseImage(
        imageBytes: widget.imageBytes,
        mimeType: widget.mimeType,
        geminiApiKey: geminiKey.isNotEmpty ? geminiKey : null,
        groqApiKey: groqKey.isNotEmpty ? groqKey : null,
        openRouterApiKey: openRouterKey.isNotEmpty ? openRouterKey : null,
        cloudflareAccountId: cfAccountId.isNotEmpty ? cfAccountId : null,
        cloudflareApiToken: cfApiToken.isNotEmpty ? cfApiToken : null,
        preferredEngine: preferredEngine,
      );

      _stepTimer?.cancel();
      if (mounted) {
        setState(() {
          _currentStepIndex = 4; // Complete all steps
        });
      }

      await Future.delayed(const Duration(milliseconds: 400));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ReviewScannedSchedulesView(
              initialEntries: parsed,
            ),
          ),
        );
      }
    } catch (e) {
      _stepTimer?.cancel();
      if (mounted) {
        final rawErr = e.toString().replaceAll('Exception: ', '');
        final isNetworkErr = rawErr.toLowerCase().contains('socket') ||
            rawErr.toLowerCase().contains('clientexception') ||
            rawErr.toLowerCase().contains('failed host lookup') ||
            rawErr.toLowerCase().contains('timeout') ||
            rawErr.toLowerCase().contains('network');

        final String dialogTitle = isNetworkErr ? 'No Internet Connection' : 'AI Scan Error';
        final IconData dialogIcon = isNetworkErr ? Icons.wifi_off_rounded : Icons.error_outline_rounded;
        final String errorBody = isNetworkErr
            ? 'Schedly requires an active internet connection to process timetable images with Vision AI models. Please connect to Wi-Fi or Mobile Data and try again.'
            : 'Could not extract timetable across available AI engines:\n\n$rawErr';

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(dialogIcon, color: const Color(0xFFDC2626), size: 24),
                const SizedBox(width: 8),
                Text(dialogTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              ],
            ),
            content: Text(
              errorBody,
              style: const TextStyle(fontSize: 13.5, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context); // Return to scanner landing to pick another image
                },
                icon: const Icon(Icons.photo_library_outlined, size: 16, color: Color(0xFF2563EB)),
                label: const Text('Try Different Image', style: TextStyle(color: Color(0xFF2563EB))),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF2563EB)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _currentStepIndex = 0;
                  });
                  _startStepSimulation();
                  _startParsing();
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry Scan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Processing',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
            children: [
              const SizedBox(height: 10),

              // Animated Target Frame with Glowing Brackets matching mockup
              _buildTargetScanner(isDark),

              const SizedBox(height: 24),

              // Headline & Subtitle matching mockup
              Text(
                'Analyzing your schedule...',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width - 64,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 13, color: Color(0xFF2563EB)),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        _getEngineLabel(ref.watch(preferredAiEngineProvider)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Extracting subjects, days, times, and venues',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                ),
              ),

              const SizedBox(height: 32),

              // Live 5-Step Progress Timeline Checklist matching mockup
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: List.generate(_stepTitles.length, (index) {
                    final isDone = index < _currentStepIndex;
                    final isActive = index == _currentStepIndex;
                    final isPending = index > _currentStepIndex;
                    final isLast = index == _stepTitles.length - 1;

                    return _buildTimelineStep(
                      title: _stepTitles[index],
                      isDone: isDone,
                      isActive: isActive,
                      isPending: isPending,
                      isLast: isLast,
                      isDark: isDark,
                    );
                  }),
                ),
              ),

              const Spacer(),

              // Bottom Warning Banner matching mockup
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : const Color(0xFFBFDBFE),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: Color(0xFF2563EB), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Please don\'t close the app while we\'re processing.',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : const Color(0xFF1E3A8A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    ),
  ),
);
}

  Widget _buildTimelineStep({
    required String title,
    required bool isDone,
    required bool isActive,
    required bool isPending,
    required bool isLast,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stepper Circle & Vertical Connecting Line
        Column(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone
                    ? const Color(0xFF10B981) // Green Done
                    : isActive
                        ? const Color(0xFF2563EB).withValues(alpha: 0.15) // Blue Ring Active
                        : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)), // Pending
                border: Border.all(
                  color: isDone
                      ? const Color(0xFF10B981)
                      : isActive
                          ? const Color(0xFF2563EB)
                          : (isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                  width: isActive ? 2 : 1.5,
                ),
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                    : isActive
                        ? const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                            ),
                          )
                        : null,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 22,
                color: isDone
                    ? const Color(0xFF10B981).withValues(alpha: 0.5)
                    : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
              ),
          ],
        ),

        const SizedBox(width: 14),

        // Step Title
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isActive || isDone ? FontWeight.w700 : FontWeight.w500,
                      color: isDone
                          ? (isDark ? Colors.white : const Color(0xFF0F172A))
                          : isActive
                              ? const Color(0xFF2563EB)
                              : (isDark ? AppColors.textSecondaryDark : const Color(0xFF94A3B8)),
                    ),
                  ),
                ),
                if (isDone)
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTargetScanner(bool isDark) {
    return Container(
      width: 136,
      height: 136,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.12),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 4 Perfectly Symmetrical Blue Corner Brackets matching mockup
          const Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(22.0),
              child: CustomPaint(
                painter: _CornerBracketsPainter(color: Color(0xFF2563EB)),
              ),
            ),
          ),

          // Pulsing Center Camera Target Circle with subtle glow
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = 0.94 + (_pulseController.value * 0.10);
              return Transform.scale(
                scale: scale,
                child: child,
              );
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2563EB).withValues(alpha: 0.06),
                border: Border.all(color: const Color(0xFF2563EB), width: 3.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x332563EB),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getEngineLabel(String engine) {
    final authState = ref.read(authProvider);
    if (authState.isGuest || !authState.isLoggedIn) {
      return 'On-Device Local AI (Offline)';
    }

    switch (engine.toLowerCase()) {
      case 'offline':
        return 'On-Device Local AI (Offline)';
      case 'groq':
        return 'Groq LPU Vision';
      case 'gemini':
        return 'Google Gemini Flash';
      case 'openrouter':
        return 'OpenRouter Vision';
      case 'cloudflare':
        return 'Cloudflare Workers AI';
      case 'auto':
      default:
        return 'Hybrid Multi-AI Cascade';
    }
  }
}

class _CornerBracketsPainter extends CustomPainter {
  final Color color;
  const _CornerBracketsPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    const cornerLength = 16.0;

    // 1. Top-Left Bracket
    final pathTL = Path()
      ..moveTo(0, cornerLength)
      ..lineTo(0, 0)
      ..lineTo(cornerLength, 0);
    canvas.drawPath(pathTL, paint);

    // 2. Top-Right Bracket
    final pathTR = Path()
      ..moveTo(size.width - cornerLength, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, cornerLength);
    canvas.drawPath(pathTR, paint);

    // 3. Bottom-Left Bracket (Fixed: exactly symmetric corner)
    final pathBL = Path()
      ..moveTo(0, size.height - cornerLength)
      ..lineTo(0, size.height)
      ..lineTo(cornerLength, size.height);
    canvas.drawPath(pathBL, paint);

    // 4. Bottom-Right Bracket
    final pathBR = Path()
      ..moveTo(size.width - cornerLength, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, size.height - cornerLength);
    canvas.drawPath(pathBR, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
