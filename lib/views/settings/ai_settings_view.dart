import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ai/ai_training_telemetry_service.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/ai_settings_provider.dart';

class AiSettingsView extends ConsumerStatefulWidget {
  const AiSettingsView({super.key});

  @override
  ConsumerState<AiSettingsView> createState() => _AiSettingsViewState();
}

class _AiSettingsViewState extends ConsumerState<AiSettingsView> {
  final _keyController = TextEditingController();
  final _cfAccountController = TextEditingController();
  final _cfTokenController = TextEditingController();
  bool _isAiContributionEnabled = true;

  @override
  void initState() {
    super.initState();
    _isAiContributionEnabled = AiTrainingTelemetryService.isTelemetryEnabled();
  }

  @override
  void dispose() {
    _keyController.dispose();
    _cfAccountController.dispose();
    _cfTokenController.dispose();
    super.dispose();
  }

  void _showEditKeyDialog({
    required String title,
    required String description,
    required String currentValue,
    required String envDefault,
    required Function(String) onSave,
    required VoidCallback onReset,
  }) {
    _keyController.text = currentValue;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) {
        bool obscure = true;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _keyController,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      hintText: envDefault.isNotEmpty ? 'Active (.env configured)' : 'Paste API key here',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20,
                          color: const Color(0xFF64748B),
                        ),
                        onPressed: () => setDialogState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                  if (envDefault.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Default key is provided in .env',
                      style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
              actions: [
                if (envDefault.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      onReset();
                      Navigator.pop(ctx);
                    },
                    child: const Text('Use Default'),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    onSave(_keyController.text.trim());
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditCloudflareDialog({
    required String currentAccountId,
    required String currentApiToken,
  }) {
    _cfAccountController.text = currentAccountId;
    _cfTokenController.text = currentApiToken;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) {
        bool obscure = true;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Cloudflare Workers AI',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configure Cloudflare Account ID and API Token for edge Llama 3.2 Vision.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _cfAccountController,
                    decoration: InputDecoration(
                      labelText: 'Account ID',
                      hintText: AppConfig.cloudflareAccountId.isNotEmpty ? 'Configured in .env' : 'Account ID',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _cfTokenController,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'API Token',
                      hintText: AppConfig.cloudflareApiToken.isNotEmpty ? 'Configured in .env' : 'API Token',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20,
                          color: const Color(0xFF64748B),
                        ),
                        onPressed: () => setDialogState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    ref.read(cloudflareAccountIdProvider.notifier).resetToDefault();
                    ref.read(cloudflareApiTokenProvider.notifier).resetToDefault();
                    Navigator.pop(ctx);
                  },
                  child: const Text('Use Default'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final accountId = _cfAccountController.text.trim();
                    final token = _cfTokenController.text.trim();
                    ref.read(cloudflareAccountIdProvider.notifier).setKey(accountId);
                    ref.read(cloudflareApiTokenProvider.notifier).setKey(token);
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final preferredEngine = ref.watch(preferredAiEngineProvider);
    final geminiKey = ref.watch(geminiApiKeyProvider);
    final groqKey = ref.watch(groqApiKeyProvider);
    final openRouterKey = ref.watch(openRouterApiKeyProvider);
    final cfId = ref.watch(cloudflareAccountIdProvider);
    final cfToken = ref.watch(cloudflareApiTokenProvider);

    final engineOptions = [
      {
        'key': 'auto',
        'title': 'Auto Multi-AI Cascade (Recommended)',
        'subtitle': 'Cloud AI (Groq/Gemini/OpenRouter/Cloudflare) + Automatic Offline fallback',
        'icon': Icons.auto_awesome_rounded,
        'color': const Color(0xFF2563EB),
      },
      {
        'key': 'offline',
        'title': 'On-Device Local AI (100% Offline)',
        'subtitle': 'Zero internet required. On-device Philippine schedule extraction engine.',
        'icon': Icons.wifi_off_rounded,
        'color': const Color(0xFF0EA5E9),
      },
      {
        'key': 'groq',
        'title': 'Groq LPU Vision',
        'subtitle': 'Sub-second speed powered by Llama 3.2 Vision preview',
        'icon': Icons.bolt_rounded,
        'color': const Color(0xFFF59E0B),
      },
      {
        'key': 'gemini',
        'title': 'Google Gemini Flash',
        'subtitle': 'Multimodal extraction via Gemini 2.5/1.5 Flash',
        'icon': Icons.auto_awesome_rounded,
        'color': const Color(0xFF10B981),
      },
      {
        'key': 'openrouter',
        'title': 'OpenRouter Vision Hub',
        'subtitle': 'Multi-model aggregator with free vision fallbacks',
        'icon': Icons.hub_rounded,
        'color': const Color(0xFF8B5CF6),
      },
      {
        'key': 'cloudflare',
        'title': 'Cloudflare Workers AI',
        'subtitle': 'Edge AI inferencing via Llama 3.2 Vision on Cloudflare',
        'icon': Icons.cloud_done_rounded,
        'color': const Color(0xFFF97316),
      },
    ];

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'AI Engines & API Keys',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.hub_rounded, color: Color(0xFF2563EB), size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Quad Multi-AI Architecture',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: Color(0xFF1E40AF)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Schedly intelligently falls back between 4 AI providers to guarantee maximum extraction success.',
                            style: TextStyle(fontSize: 12, color: isDark ? AppColors.textSecondaryDark : const Color(0xFF334155), height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Section 1: Preferred Engine
              _buildSectionHeader('DEFAULT ENGINE MODE', isDark),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: engineOptions.map((opt) {
                    final key = opt['key'] as String;
                    final isSelected = preferredEngine == key;
                    final color = opt['color'] as Color;

                    return Column(
                      children: [
                        ListTile(
                          onTap: () => ref.read(preferredAiEngineProvider.notifier).setKey(key),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(opt['icon'] as IconData, color: color, size: 20),
                          ),
                          title: Text(
                            opt['title'] as String,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                              fontSize: 13.5,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          subtitle: Text(
                            opt['subtitle'] as String,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                            ),
                          ),
                          trailing: Icon(
                            isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                            size: 20,
                          ),
                        ),
                        if (key != 'cloudflare')
                          Divider(height: 1, indent: 56, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                      ],
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 24),

              // Section 2: API Keys for 4 Engines
              _buildSectionHeader('API KEYS & CREDENTIALS', isDark),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    // 1. Groq
                    _buildApiKeyTile(
                      title: 'Groq LPU Vision Key',
                      subtitle: 'Ultra-fast Llama 3.2 11B / 90B Vision',
                      isConfigured: groqKey.isNotEmpty || AppConfig.defaultGroqApiKey.isNotEmpty,
                      icon: Icons.bolt_rounded,
                      iconColor: const Color(0xFFF59E0B),
                      isDark: isDark,
                      onTap: () => _showEditKeyDialog(
                        title: 'Groq API Key',
                        description: 'Enter your Groq cloud API key (starts with gsk_)',
                        currentValue: groqKey,
                        envDefault: AppConfig.defaultGroqApiKey,
                        onSave: (k) => ref.read(groqApiKeyProvider.notifier).setKey(k),
                        onReset: () => ref.read(groqApiKeyProvider.notifier).resetToDefault(),
                      ),
                    ),
                    Divider(height: 1, indent: 56, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),

                    // 2. Gemini
                    _buildApiKeyTile(
                      title: 'Google Gemini Key',
                      subtitle: 'Multimodal Gemini Flash Vision',
                      isConfigured: geminiKey.isNotEmpty || AppConfig.defaultGeminiApiKey.isNotEmpty,
                      icon: Icons.auto_awesome_rounded,
                      iconColor: const Color(0xFF10B981),
                      isDark: isDark,
                      onTap: () => _showEditKeyDialog(
                        title: 'Google Gemini API Key',
                        description: 'Enter your Google AI Studio API key',
                        currentValue: geminiKey,
                        envDefault: AppConfig.defaultGeminiApiKey,
                        onSave: (k) => ref.read(geminiApiKeyProvider.notifier).setKey(k),
                        onReset: () => ref.read(geminiApiKeyProvider.notifier).resetToDefault(),
                      ),
                    ),
                    Divider(height: 1, indent: 56, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),

                    // 3. OpenRouter
                    _buildApiKeyTile(
                      title: 'OpenRouter Key',
                      subtitle: 'Access to Qwen, Llama & free vision models',
                      isConfigured: openRouterKey.isNotEmpty || AppConfig.defaultOpenRouterApiKey.isNotEmpty,
                      icon: Icons.hub_rounded,
                      iconColor: const Color(0xFF8B5CF6),
                      isDark: isDark,
                      onTap: () => _showEditKeyDialog(
                        title: 'OpenRouter API Key',
                        description: 'Enter your OpenRouter key (starts with sk-or-)',
                        currentValue: openRouterKey,
                        envDefault: AppConfig.defaultOpenRouterApiKey,
                        onSave: (k) => ref.read(openRouterApiKeyProvider.notifier).setKey(k),
                        onReset: () => ref.read(openRouterApiKeyProvider.notifier).resetToDefault(),
                      ),
                    ),
                    Divider(height: 1, indent: 56, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),

                    // 4. Cloudflare
                    _buildApiKeyTile(
                      title: 'Cloudflare Workers AI',
                      subtitle: 'Account ID & API Token for Edge AI',
                      isConfigured: (cfId.isNotEmpty && cfToken.isNotEmpty) ||
                          (AppConfig.cloudflareAccountId.isNotEmpty && AppConfig.cloudflareApiToken.isNotEmpty),
                      icon: Icons.cloud_done_rounded,
                      iconColor: const Color(0xFFF97316),
                      isDark: isDark,
                      onTap: () => _showEditCloudflareDialog(
                        currentAccountId: cfId,
                        currentApiToken: cfToken,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Section 3: AI Dataset & Privacy Contribution
              _buildSectionHeader('AI IMPROVEMENT & DATA PRIVACY', isDark),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
                ),
                child: SwitchListTile(
                  value: _isAiContributionEnabled,
                  onChanged: (val) {
                    setState(() => _isAiContributionEnabled = val);
                    AiTrainingTelemetryService.setTelemetryEnabled(val);
                  },
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.psychology_rounded, color: Color(0xFF2563EB), size: 20),
                  ),
                  title: Text(
                    'Help Improve Offline AI',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  subtitle: Text(
                    'Anonymously share schedule formatting and corrected OCR labels to help train smarter offline AI models. Personal IDs and sensitive details are never collected.',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.35,
                      color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                    ),
                  ),
                  activeTrackColor: const Color(0xFF2563EB),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    ),
  ),
);
}

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildApiKeyTile({
    required String title,
    required String subtitle,
    required bool isConfigured,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isConfigured ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isConfigured ? 'Ready' : 'Not Set',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: isConfigured ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 11.5,
          color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
    );
  }
}
