pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
    // Firebase Cloud Messaging (push notifications). Applied per-module in
    // android/app/build.gradle.kts. Requires android/app/google-services.json
    // to exist — see ENGINEERING.md / the Firebase setup steps for how to
    // generate it. Without that file, this plugin fails the build by design
    // (that's the correct behavior once Firebase is wired up for real, not a
    // bug — do not silence it).
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
