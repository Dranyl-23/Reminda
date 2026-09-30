/// Compile-time build configuration read from --dart-define values.
///
/// For production Windows builds inject secrets at build time:
/// ```
/// flutter build windows --release \
///   --dart-define=GEMINI_API_KEY=<key> \
///   --dart-define=GROQ_API_KEY=<key>
/// ```
///
/// For local development, a .env file is still loaded as a fallback
/// (see main.dart). This class provides a single source of truth so
/// all services consistently read from the same compile-time constants.
class BuildConfig {
  BuildConfig._();

  /// Gemini generative-AI API key.
  /// Empty string when not injected at compile time — falls back to dotenv.
  static const String geminiApiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  /// Groq API key used for primary OCR.
  /// Empty string when not injected at compile time — falls back to dotenv.
  static const String groqApiKey =
      String.fromEnvironment('GROQ_API_KEY', defaultValue: '');

  /// True when at least one key has been baked in at compile time.
  /// When false, the runtime .env file must supply the keys.
  static bool get hasCompileTimeKeys =>
      geminiApiKey.isNotEmpty || groqApiKey.isNotEmpty;
}
