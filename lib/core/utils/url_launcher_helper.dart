import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Helper to safely and resiliently launch external URLs in the device browser.
/// Handles Android 11+ package visibility restrictions and provides clipboard fallback.
Future<void> launchAppUrl(BuildContext context, String urlString) async {
  final cleanUrl = urlString.trim();
  if (cleanUrl.isEmpty) return;

  try {
    final uri = Uri.parse(cleanUrl);

    // 1. First attempt: Launch in external browser
    bool launched = false;
    try {
      launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}

    // 2. Second attempt: Platform default if external application failed
    if (!launched) {
      try {
        launched = await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
      } catch (_) {}
    }

    // 3. Fallback: If device couldn't open directly, copy to clipboard
    if (!launched && context.mounted) {
      await Clipboard.setData(ClipboardData(text: cleanUrl));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Update link copied to clipboard! Paste into your browser.'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  } catch (e) {
    if (context.mounted) {
      await Clipboard.setData(ClipboardData(text: cleanUrl));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update link copied to clipboard! ($cleanUrl)'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
