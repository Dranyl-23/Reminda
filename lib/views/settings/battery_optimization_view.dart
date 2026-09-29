import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class BatteryOptimizationView extends StatelessWidget {
  const BatteryOptimizationView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarm & Notification Guide'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(20),
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.battery_alert_rounded, color: AppColors.warning, size: 28),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'To make sure your schedule alarms fire on time even when your phone is asleep, please check these phone settings.',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.4),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'DEVICE SETUP INSTRUCTIONS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondaryLight,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),

          _buildBrandCard(
            context,
            brand: 'Xiaomi / Poco / Redmi (MIUI & HyperOS)',
            icon: Icons.phone_android_rounded,
            steps: [
              'Go to Settings > Apps > Manage Apps > Reminda',
              'Enable "Autostart"',
              'Set Battery Saver to "No restrictions"',
              'Enable "Show on Lock screen" and "Pop-up notifications"',
            ],
            isDark: isDark,
          ),

          _buildBrandCard(
            context,
            brand: 'Samsung (One UI)',
            icon: Icons.smartphone_rounded,
            steps: [
              'Go to Settings > Apps > Reminda > Battery',
              'Select "Unrestricted"',
              'Go to Settings > Battery > Background usage limits',
              'Ensure Reminda is in "Never sleeping apps"',
            ],
            isDark: isDark,
          ),

          _buildBrandCard(
            context,
            brand: 'Oppo / Realme (ColorOS / Realme UI)',
            icon: Icons.phone_iphone_rounded,
            steps: [
              'Go to Settings > App Management > Reminda',
              'Enable "Allow Auto-launch" & "Allow background activity"',
              'Turn off battery optimization for the app',
            ],
            isDark: isDark,
          ),

          _buildBrandCard(
            context,
            brand: 'Vivo / iQOO (Funtouch OS)',
            icon: Icons.stay_current_portrait_rounded,
            steps: [
              'Go to Settings > Battery > High background power consumption',
              'Toggle Reminda to ON',
              'Enable Auto-start in App Manager',
            ],
            isDark: isDark,
          ),

          const SizedBox(height: 20),
        ],
      ),
    ),
  ),
);
}

  Widget _buildBrandCard(
    BuildContext context, {
    required String brand,
    required IconData icon,
    required List<String> steps,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  brand,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...steps.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.key + 1}. ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppColors.primary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
