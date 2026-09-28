import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/url_launcher_helper.dart';
import '../../../providers/announcement_provider.dart';

class AnnouncementBanner extends ConsumerWidget {
  const AnnouncementBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcement = ref.watch(currentVisibleAnnouncementProvider);
    if (announcement == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Type styling
    Color bg;
    Color border;
    Color iconColor;
    IconData icon;

    switch (announcement.type) {
      case 'warning':
        bg = isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7);
        border = const Color(0xFFF59E0B);
        iconColor = const Color(0xFFD97706);
        icon = Icons.warning_amber_rounded;
        break;
      case 'urgent':
        bg = isDark ? const Color(0xFF4C0519) : const Color(0xFFFFE4E6);
        border = const Color(0xFFF43F5E);
        iconColor = const Color(0xFFE11D48);
        icon = Icons.error_outline_rounded;
        break;
      case 'promo':
        bg = isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF);
        border = const Color(0xFF6366F1);
        iconColor = const Color(0xFF4F46E5);
        icon = Icons.auto_awesome_rounded;
        break;
      default:
        bg = isDark ? const Color(0xFF0C2340) : const Color(0xFFEFF6FF);
        border = const Color(0xFF3B82F6);
        iconColor = const Color(0xFF2563EB);
        icon = Icons.info_outline_rounded;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border.withValues(alpha: 0.4), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: border.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Icon + Title + Close Button
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    announcement.title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    final current = ref.read(dismissedAnnouncementsProvider);
                    ref.read(dismissedAnnouncementsProvider.notifier).state = {
                      ...current,
                      announcement.id,
                    };
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Message
            Padding(
              padding: const EdgeInsets.only(left: 34),
              child: Text(
                announcement.message,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                ),
              ),
            ),

            // Action Button (Optional)
            if (announcement.actionLabel.isNotEmpty) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 34),
                child: GestureDetector(
                  onTap: () async {
                    if (announcement.actionUrl.trim().isNotEmpty) {
                      await launchAppUrl(context, announcement.actionUrl);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: iconColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      announcement.actionLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
