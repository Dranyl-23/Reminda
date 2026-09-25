import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/config/app_config.dart';

const String _settingsBox = 'app_settings_box';

class AiStringSettingNotifier extends StateNotifier<String> {
  final String keyName;
  final String Function() defaultGetter;
  Box? _box;

  AiStringSettingNotifier({
    required this.keyName,
    required this.defaultGetter,
  }) : super(defaultGetter()) {
    _init();
  }

  Future<void> _init() async {
    _box = Hive.isBoxOpen(_settingsBox)
        ? Hive.box(_settingsBox)
        : await Hive.openBox(_settingsBox);
    final saved = _box?.get(keyName, defaultValue: defaultGetter()) as String?;
    if (!mounted) return;
    state = (saved != null && saved.trim().isNotEmpty) ? saved.trim() : defaultGetter();
  }

  Future<void> setKey(String key) async {
    _box = Hive.isBoxOpen(_settingsBox)
        ? Hive.box(_settingsBox)
        : await Hive.openBox(_settingsBox);
    final trimmed = key.trim();
    final finalValue = trimmed.isNotEmpty ? trimmed : defaultGetter();
    await _box?.put(keyName, finalValue);
    if (!mounted) return;
    state = finalValue;
  }

  Future<void> resetToDefault() async {
    _box = Hive.isBoxOpen(_settingsBox)
        ? Hive.box(_settingsBox)
        : await Hive.openBox(_settingsBox);
    await _box?.delete(keyName);
    if (!mounted) return;
    state = defaultGetter();
  }
}

// 1. Google Gemini Key Provider
final geminiApiKeyProvider =
    StateNotifierProvider<AiStringSettingNotifier, String>((ref) {
  return AiStringSettingNotifier(
    keyName: 'gemini_api_key',
    defaultGetter: () => AppConfig.defaultGeminiApiKey,
  );
});

// 2. Groq Key Provider
final groqApiKeyProvider =
    StateNotifierProvider<AiStringSettingNotifier, String>((ref) {
  return AiStringSettingNotifier(
    keyName: 'groq_api_key',
    defaultGetter: () => AppConfig.defaultGroqApiKey,
  );
});

// 3. OpenRouter Key Provider
final openRouterApiKeyProvider =
    StateNotifierProvider<AiStringSettingNotifier, String>((ref) {
  return AiStringSettingNotifier(
    keyName: 'openrouter_api_key',
    defaultGetter: () => AppConfig.defaultOpenRouterApiKey,
  );
});

// 4. Cloudflare Account ID Provider
final cloudflareAccountIdProvider =
    StateNotifierProvider<AiStringSettingNotifier, String>((ref) {
  return AiStringSettingNotifier(
    keyName: 'cloudflare_account_id',
    defaultGetter: () => AppConfig.cloudflareAccountId,
  );
});

// 5. Cloudflare API Token Provider
final cloudflareApiTokenProvider =
    StateNotifierProvider<AiStringSettingNotifier, String>((ref) {
  return AiStringSettingNotifier(
    keyName: 'cloudflare_api_token',
    defaultGetter: () => AppConfig.cloudflareApiToken,
  );
});

// Preferred Engine: 'auto', 'groq', 'gemini', 'openrouter', 'cloudflare'
final preferredAiEngineProvider =
    StateNotifierProvider<AiStringSettingNotifier, String>((ref) {
  return AiStringSettingNotifier(
    keyName: 'preferred_ai_engine',
    defaultGetter: () => 'auto',
  );
});

// Check if at least one AI engine has valid credentials
final hasAnyAiConfiguredProvider = Provider<bool>((ref) {
  final gemini = ref.watch(geminiApiKeyProvider);
  final groq = ref.watch(groqApiKeyProvider);
  final openRouter = ref.watch(openRouterApiKeyProvider);
  final cfId = ref.watch(cloudflareAccountIdProvider);
  final cfToken = ref.watch(cloudflareApiTokenProvider);

  return gemini.isNotEmpty ||
      groq.isNotEmpty ||
      openRouter.isNotEmpty ||
      (cfId.isNotEmpty && cfToken.isNotEmpty) ||
      AppConfig.defaultGeminiApiKey.isNotEmpty ||
      AppConfig.defaultGroqApiKey.isNotEmpty ||
      AppConfig.defaultOpenRouterApiKey.isNotEmpty ||
      (AppConfig.cloudflareAccountId.isNotEmpty && AppConfig.cloudflareApiToken.isNotEmpty);
});
