import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase Cloud Messaging. Reads android/app/google-services.json, which
    // does not exist in this checkout yet — until a human adds a real one
    // (see the Firebase console setup steps), this plugin will fail the
    // build. That failure is the Google Services plugin's own expected
    // behavior for a missing config file, not a bug introduced here.
    id("com.google.gms.google-services")
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
    // Cannot be lowered below 36: several transitive AndroidX/Firebase
    // dependencies (androidx.activity 1.12.4, androidx.core-ktx/core 1.18.0)
    // hard-require compileSdk >= 36 and fail the build otherwise (confirmed
    // by trying compileSdk=34). compileSdk only affects which APIs are
    // available at compile time -- it is not itself a device-install-time
    // compatibility gate, so this was never the cause of install failures.
    compileSdk = 36
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

// Ship a release APK a human can identify. Gradle's own output name is left
// as `app-release.apk` on purpose -- `flutter build apk` looks that exact
// filename up by hand (flutter_tools' `_apkFilesFor`) and fails the build
// with "Gradle build failed to produce an .apk file" if it is renamed. So
// this writes a *second*, properly named copy next to it rather than
// renaming the first. `scripts/build-release.ps1` publishes under the same
// name, so what a rider downloads is `Teman-Kereta.<versi>.apk`.
val friendlyReleaseApkName = "Teman-Kereta.${flutter.versionName}.apk"
val releaseApkDirectory = layout.buildDirectory.dir("outputs/apk/release")
tasks.matching { it.name == "assembleRelease" }.configureEach {
    doLast {
        val directory = releaseApkDirectory.get().asFile
        val built = directory.resolve("app-release.apk")
        if (built.exists()) {
            built.copyTo(directory.resolve(friendlyReleaseApkName), overwrite = true)
        }
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
