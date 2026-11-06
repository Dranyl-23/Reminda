/// Compile-time build configuration read from --dart-define values.
///
/// Production builds route cloud AI extraction through the authenticated
/// Next.js Server AI Proxy (`/api/ai/parse`) so provider API keys (Gemini, Groq,
/// OpenRouter, Cloudflare) are NEVER baked into client binaries or shipped in
/// a `.env` file alongside the executable:
/// ```
/// flutter build windows --release \
///   --dart-define=AI_PROXY_URL=https://your-admin-portal.vercel.app/api/ai/parse
/// ```
class BuildConfig {
  BuildConfig._();

  /// Authenticated Server AI Proxy endpoint (`/api/ai/parse`).
  static const String aiProxyUrl =
      String.fromEnvironment('AI_PROXY_URL', defaultValue: '');

  /// Google OAuth Web/Server Client ID (public identifier, not a secret).
  static const String googleOAuthClientId =
      String.fromEnvironment('GOOGLE_OAUTH_CLIENT_ID', defaultValue: '');

  /// True when a compile-time proxy URL has been configured.
  static bool get hasCompileTimeConfig => aiProxyUrl.isNotEmpty;
}
