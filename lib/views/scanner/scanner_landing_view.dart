import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/schedule_provider.dart';
import 'ocr_processing_view.dart';

class ScannerLandingView extends ConsumerStatefulWidget {
  const ScannerLandingView({super.key});

  @override
  ConsumerState<ScannerLandingView> createState() => _ScannerLandingViewState();
}

class _ScannerLandingViewState extends ConsumerState<ScannerLandingView> {
  final ImagePicker _picker = ImagePicker();

  /// Always returns true because ScheduleParserService cascades from
  /// Server Proxy (/api/ai/parse) -> Cloud AI Keys -> Direct PDF Text Extractor -> On-Device Offline AI.
  bool _checkApiKey() {
    return true;
  }

  Future<void> _pickImage(ImageSource source) async {
    if (!_checkApiKey()) return;
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
      );

      if (pickedFile == null || !mounted) return;

      final File file = File(pickedFile.path);
      final Uint8List bytes = await file.readAsBytes();

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OcrProcessingView(
            imageFile: file,
            imageBytes: bytes,
            mimeType: 'image/jpeg',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick image: $e')),
        );
      }
    }
  }

  Future<void> _pickDocument() async {
    if (!_checkApiKey()) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
        withData: true,
      );

      if (result == null || result.files.isEmpty || !mounted) return;
      final file = result.files.first;

      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }

      if (bytes == null || !mounted) return;

      final ext = file.extension?.toLowerCase() ?? 'pdf';
      final mimeType = switch (ext) {
        'pdf' => 'application/pdf',
        'png' => 'image/png',
        'webp' => 'image/webp',
        'heic' => 'image/heic',
        _ => 'image/jpeg',
      };
      final fileObj = file.path != null ? File(file.path!) : null;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OcrProcessingView(
            imageFile: fileObj,
            imageBytes: bytes!,
            mimeType: mimeType,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load file: $e')),
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
          'Scan Schedule',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            children: [
              const SizedBox(height: 10),

              // Hero Illustration
              _buildHeroIllustration(isDark),

              const SizedBox(height: 24),

              // Title & Description matching mockup
              Text(
                'Scan your schedule',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Take a photo or upload an image of your class schedule, work shift, or duty roster.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Quad-AI Status Indicator
              if (!ref.watch(hasAnyAiConfiguredProvider))
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'AI Configuration Required',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF991B1B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Configure Groq, Gemini, OpenRouter, or Cloudflare keys in Settings.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt_rounded, size: 15, color: Color(0xFF2563EB)),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Quad-AI Active: Groq · Gemini · Cloudflare · OpenRouter',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),

              // Primary Action 1: Take Photo
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded, size: 20),
                  label: const Text(
                    'Take Photo',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Primary Action 2: Choose from Gallery
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded, size: 20, color: Color(0xFF1D4ED8)),
                  label: const Text(
                    'Choose from Gallery',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
                    side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Primary Action 3: Direct PDF / COR Import (Zero-Blur Parsing)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _pickDocument,
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 20, color: Color(0xFFDC2626)),
                  label: const Text(
                    'Import PDF / COR (Zero-Blur)',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.surfaceDark : const Color(0xFFFEF2F2),
                    side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Tips For Best Results Card matching mockup
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lightbulb_outline_rounded, size: 18, color: Color(0xFFF59E0B)),
                        SizedBox(width: 8),
                        Text(
                          'Tips for best results:',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildTipBullet('Import your school PDF / COR directly for 100% zero-blur accuracy', isDark),
                    const SizedBox(height: 4),
                    _buildTipBullet('Make sure the image is clear and well-lit', isDark),
                    const SizedBox(height: 4),
                    _buildTipBullet('Avoid blurry or tilted photos', isDark),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipBullet(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 24.0),
      child: Text(
        '• $text',
        style: TextStyle(
          fontSize: 12.5,
          color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildHeroIllustration(bool isDark) {
    return Center(
      child: Container(
        height: 180,
        alignment: Alignment.center,
        child: Image.asset(
          'assets/images/3D Camera Scanning Schedule Document.png',
          height: 175,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.document_scanner_rounded,
              size: 84,
              color: Color(0xFF2563EB),
            );
          },
        ),
      ),
    );
  }
}
