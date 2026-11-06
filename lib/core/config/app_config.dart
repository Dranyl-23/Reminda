import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../constants/build_config.dart';

class AppConfig {
  /// Default Gemini API Key for local non-release development only.
  /// Production builds must use the authenticated Server Proxy (`aiProxyUrl`)
  /// or user-supplied BYOK keys in AI Settings.
  static String get defaultGeminiApiKey {
    if (kReleaseMode) return '';
    try {
      final envKey = dotenv.env['GEMINI_API_KEY'];
      if (envKey != null &&
          envKey.trim().isNotEmpty &&
          !envKey.contains('your_gemini_api_key')) {
        return envKey.trim();
      }
    } catch (_) {}
    return '';
  }

  /// Default Groq API Key for local non-release development only.
  static String get defaultGroqApiKey {
    if (kReleaseMode) return '';
    try {
      final envKey = dotenv.env['GROQ_API_KEY'];
      if (envKey != null &&
          envKey.trim().isNotEmpty &&
          !envKey.contains('your_groq_api_key')) {
        return envKey.trim();
      }
    } catch (_) {}
    return '';
  }

  /// Default OpenRouter API Key for local non-release development only.
  static String get defaultOpenRouterApiKey {
    if (kReleaseMode) return '';
    try {
      final envKey = dotenv.env['OPENROUTER_API_KEY'];
      if (envKey != null &&
          envKey.trim().isNotEmpty &&
          !envKey.contains('your_openrouter_api_key')) {
        return envKey.trim();
      }
    } catch (_) {}
    return '';
  }

  /// Default Cloudflare Account ID for local non-release development only.
  static String get cloudflareAccountId {
    if (kReleaseMode) return '';
    try {
      final envVal = dotenv.env['CLOUDFLARE_ACCOUNT_ID'];
      if (envVal != null &&
          envVal.trim().isNotEmpty &&
          !envVal.contains('your_')) {
        return envVal.trim();
      }
    } catch (_) {}
    return '';
  }

  /// Default Cloudflare API Token for local non-release development only.
  static String get cloudflareApiToken {
    if (kReleaseMode) return '';
    try {
      final envVal = dotenv.env['CLOUDFLARE_API_TOKEN'];
      if (envVal != null &&
          envVal.trim().isNotEmpty &&
          !envVal.contains('your_')) {
        return envVal.trim();
      }
    } catch (_) {}
    return '';
  }

  /// Retrieves the Google OAuth server/web client ID (public identifier).
  static String get googleOAuthClientId {
    if (BuildConfig.googleOAuthClientId.isNotEmpty) {
      return BuildConfig.googleOAuthClientId;
    }
    try {
      final clientId = dotenv.env['GOOGLE_OAUTH_CLIENT_ID'];
      if (clientId != null &&
          clientId.trim().isNotEmpty &&
          !clientId.contains('your_')) {
        return clientId.trim();
      }
    } catch (_) {}
    return '';
  }

  /// Retrieves the Next.js Admin Portal AI Proxy URL (`/api/ai/parse`).
  static String get aiProxyUrl {
    if (BuildConfig.aiProxyUrl.isNotEmpty) {
      return BuildConfig.aiProxyUrl;
    }
    try {
      final url = dotenv.env['AI_PROXY_URL'];
      if (url != null && url.trim().isNotEmpty && !url.contains('your_')) {
        return url.trim();
      }
    } catch (_) {}
    return '';
  }
}
