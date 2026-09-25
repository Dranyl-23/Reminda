# Flutter Local Notifications & Gson ProGuard Rules
# Preserves generic signatures and TypeToken used for notification cancellation & scheduling in release builds

-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Suppress missing class warnings for Play Store deferred components
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
-dontwarn **

# Keep Gson TypeToken and serialization
-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Keep Flutter Local Notifications Plugin classes
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Keep Flutter & Native methods
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }

# Keep Android generated Resource IDs (R$raw, R$drawable, R$mipmap)
-keepclassmembers class **.R$* {
    public static <fields>;
}
