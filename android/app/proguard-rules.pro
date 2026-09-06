# Flutter Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }
-keep class io.flutter.notifier.** { *; }
-dontwarn io.flutter.embedding.**

# Keep generated plugin registrants
-keep class io.flutter.plugins.** { *; }

# Drift / SQLite rules
-keep class * extends javax.microedition.khronos.egl.EGL10 { *; }

# MapLibre
-keep class com.mapbox.** { *; }
-keep class org.maplibre.** { *; }
