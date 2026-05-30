# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# PhonePe Payment SDK
-keep class com.phonepe.intent.sdk.** { *; }
-keep class com.phonepe.android.** { *; }

# Play Core (referenced by Flutter deferred components but not used)
-dontwarn com.google.android.play.core.**

# Prevent stripping of Gson/JSON models used by plugins
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
