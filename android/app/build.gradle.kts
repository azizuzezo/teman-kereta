import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Real release signing, read from android/key.properties (gitignored, never
// committed — see .gitignore's `android/key.properties`/`*.jks` entries).
// Falls back to debug signing with a warning when that file is absent (a
// fresh checkout, or CI without the real keystore) so the build never
// hard-fails; only a build made with the real keystore present is a
// genuine release artifact.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "id.temankereta.teman_kereta"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "id.temankereta.teman_kereta"
        minSdk = 24
        targetSdk = 36
        multiDexEnabled = true
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "No android/key.properties found — release build is falling back to " +
                        "the DEBUG signing key. This is not a real release artifact. " +
                        "See ENGINEERING.md's \"Release signing\" section.",
                )
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Required by flutter_local_notifications for java.time APIs on older Android versions.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Android's official geofencing client. It performs geofence evaluation on-device;
    // no Teman Kereta API, deployment target, or application secret is configured here.
    implementation("com.google.android.gms:play-services-location:21.3.0")
}
