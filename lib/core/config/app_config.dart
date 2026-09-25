import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  /// Securely retrieves Google Gemini AI API Key exclusively from .env file
  static String get defaultGeminiApiKey {
    try {
      final envKey = dotenv.env['GEMINI_API_KEY'];
      if (envKey != null && envKey.trim().isNotEmpty && !envKey.contains('your_gemini_api_key')) {
        return envKey.trim();
      }
    } catch (_) {}
    return '';
  }

  /// Securely retrieves Groq AI API Key exclusively from .env file
  static String get defaultGroqApiKey {
    try {
      final envKey = dotenv.env['GROQ_API_KEY'];
      if (envKey != null && envKey.trim().isNotEmpty && !envKey.contains('your_groq_api_key')) {
        return envKey.trim();
      }
    } catch (_) {}
    return '';
  }

  /// Securely retrieves OpenRouter AI API Key exclusively from .env file
  static String get defaultOpenRouterApiKey {
    try {
      final envKey = dotenv.env['OPENROUTER_API_KEY'];
      if (envKey != null && envKey.trim().isNotEmpty && !envKey.contains('your_openrouter_api_key')) {
        return envKey.trim();
      }
    } catch (_) {}
    return '';
  }

  /// Securely retrieves Cloudflare Account ID exclusively from .env file
  static String get cloudflareAccountId {
    try {
      final envVal = dotenv.env['CLOUDFLARE_ACCOUNT_ID'];
      if (envVal != null && envVal.trim().isNotEmpty && !envVal.contains('your_')) {
        return envVal.trim();
      }
    } catch (_) {}
    return '';
  }

  /// Securely retrieves Cloudflare API Token exclusively from .env file
  static String get cloudflareApiToken {
    try {
      final envVal = dotenv.env['CLOUDFLARE_API_TOKEN'];
      if (envVal != null && envVal.trim().isNotEmpty && !envVal.contains('your_')) {
        return envVal.trim();
      }
    } catch (_) {}
    return '';
  }

  /// Retrieves the Google OAuth server/web client ID exclusively from .env file.
  /// Used by GoogleSignIn to validate ID tokens server-side.
  static String get googleOAuthClientId {
    try {
      final clientId = dotenv.env['GOOGLE_OAUTH_CLIENT_ID'];
      if (clientId != null && clientId.trim().isNotEmpty && !clientId.contains('your_')) {
        return clientId.trim();
      }
    } catch (_) {}
    return '';
  }

  /// Retrieves the Next.js Admin Portal AI Proxy URL (/api/ai/parse) if configured.
  static String get aiProxyUrl {
    try {
      final url = dotenv.env['AI_PROXY_URL'];
      if (url != null && url.trim().isNotEmpty && !url.contains('your_')) {
        return url.trim();
      }
    } catch (_) {}
    return '';
  }
}

