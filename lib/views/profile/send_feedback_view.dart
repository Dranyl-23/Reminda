import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_version.dart';
import '../../core/database/firestore_instance.dart';
import '../../providers/auth_provider.dart';

class SendFeedbackView extends ConsumerStatefulWidget {
  const SendFeedbackView({super.key});

  @override
  ConsumerState<SendFeedbackView> createState() => _SendFeedbackViewState();
}

class _SendFeedbackViewState extends ConsumerState<SendFeedbackView> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  int _selectedRating = 5;
  String _selectedCategory = 'General Feedback';
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _categories = [
    {
      'label': 'General Feedback',
      'icon': Icons.favorite_border_rounded,
      'color': Color(0xFFEC4899),
    },
    {
      'label': 'Feature Request',
      'icon': Icons.lightbulb_outline_rounded,
      'color': Color(0xFFEAB308),
    },
    {
      'label': 'Bug Report',
      'icon': Icons.bug_report_outlined,
      'color': Color(0xFFEF4444),
    },
    {
      'label': 'Scanner / OCR Issue',
      'icon': Icons.document_scanner_outlined,
      'color': Color(0xFF2563EB),
    },
  ];

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email != null && user!.email!.isNotEmpty) {
      _emailController.text = user.email!;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your feedback or suggestions.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    if (message.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please write at least a few words so we can understand.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final auth = ref.read(authProvider);

      final feedbackData = {
        'rating': _selectedRating,
        'category': _selectedCategory,
        'message': message,
        'contactEmail': _emailController.text.trim(),
        'userId': user?.uid ?? (auth.isGuest ? 'guest' : 'anonymous'),
        'userName': user?.displayName ?? (auth.isGuest ? 'Guest User' : 'User'),
        'userPhotoUrl': user?.photoURL ?? '',
        'appVersion': AppVersion.fullVersion,
        'platform': Platform.isAndroid ? 'Android' : (Platform.isIOS ? 'iOS' : 'Other'),
        'timestamp': FieldValue.serverTimestamp(),
        'createdAtIso': DateTime.now().toIso8601String(),
      };

      await appFirestore
          .collection('user_feedback')
          .add(feedbackData)
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      // Graceful offline feedback dialog
      _showSuccessDialog(isOffline: true);
    }
  }

  void _showSuccessDialog({bool isOffline = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Column(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 52),
              SizedBox(height: 12),
              Text(
                'Thank You!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Text(
            isOffline
                ? 'Your feedback has been noted. Thank you for helping us make Reminda better!'
                : 'Your feedback has been successfully submitted directly to the developer. We truly appreciate your support!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: isDark ? AppColors.textSecondaryDark : const Color(0xFF475569),
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Send Feedback',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
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
                        Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 24),
                        SizedBox(width: 10),
                        Text(
                          'We Value Your Input!',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Found a bug, want a new feature, or want to suggest a school/workplace? Tell us below!',
                      style: TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.35),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // 1. Star Rating
              _buildFieldLabel('HOW WOULD YOU RATE YOUR EXPERIENCE?', isDark),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(5, (index) {
                    final starValue = index + 1;
                    final isFilled = starValue <= _selectedRating;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedRating = starValue),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: AnimatedScale(
                          scale: isFilled ? 1.15 : 1.0,
                          duration: const Duration(milliseconds: 150),
                          child: Icon(
                            isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: isFilled ? const Color(0xFFEAB308) : const Color(0xFF94A3B8),
                            size: 36,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 20),

              // 2. Feedback Category
              _buildFieldLabel('CATEGORY', isDark),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((cat) {
                  final String label = cat['label'] as String;
                  final IconData icon = cat['icon'] as IconData;
                  final Color catColor = cat['color'] as Color;
                  final bool isSelected = _selectedCategory == label;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = label),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? catColor.withValues(alpha: isDark ? 0.25 : 0.12)
                            : (isDark ? AppColors.surfaceDark : Colors.white),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? catColor : (isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
                          width: isSelected ? 1.8 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 17, color: isSelected ? catColor : const Color(0xFF64748B)),
                          const SizedBox(width: 7),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? catColor : (isDark ? Colors.white70 : const Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // 3. Message Area
              _buildFieldLabel('YOUR MESSAGE', isDark),
              TextField(
                controller: _messageController,
                maxLines: 5,
                maxLength: 1000,
                style: const TextStyle(fontSize: 14.5),
                decoration: InputDecoration(
                  hintText: 'Share your feedback, bug details, or feature requests here...',
                  hintStyle: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? AppColors.textSecondaryDark : const Color(0xFF94A3B8),
                  ),
                  filled: true,
                  fillColor: isDark ? AppColors.surfaceDark : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 4. Optional Contact Email
              _buildFieldLabel('CONTACT EMAIL (OPTIONAL)', isDark),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(fontSize: 14.5),
                decoration: InputDecoration(
                  hintText: 'e.g. yourname@gmail.com',
                  prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20, color: Color(0xFF2563EB)),
                  filled: true,
                  fillColor: isDark ? AppColors.surfaceDark : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // 5. Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitFeedback,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    _isSubmitting ? 'Sending Feedback...' : 'Submit Feedback',
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ),
  ),
);
}

  Widget _buildFieldLabel(String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
          color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
        ),
      ),
    );
  }
}
