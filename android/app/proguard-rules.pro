# Flutter
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**

# Kotlin Metadata
-keep class kotlin.Metadata { *; }

# Common AndroidX (safe keep for reflection-heavy libs)
-dontwarn androidx.**
