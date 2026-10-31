import java.net.URI

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.kitty191.schedule"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.kitty191.schedule"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    testOptions {
        unitTests.isIncludeAndroidResources = true
        unitTests.all {
            // Robolectric 4.17 uses SharedSecrets to emulate framework file descriptors.
            it.jvmArgs("--add-exports=java.base/jdk.internal.access=ALL-UNNAMED")
            it.systemProperty("robolectric.dependency.repo.url", "https://repo.maven.apache.org/maven2")
            for (property in listOf("javax.net.ssl.trustStore", "javax.net.ssl.trustStoreType")) {
                System.getProperty(property)?.let { value -> it.systemProperty(property, value) }
            }
            // Robolectric's SDK resolver runs in a child JVM, outside Gradle's
            // dependency resolver. Honor the same session HTTP proxy there.
            for (scheme in listOf("http", "https")) {
                val proxy = providers.environmentVariable("${scheme.uppercase()}_PROXY").orNull?.let(::URI)
                if (proxy?.host != null) {
                    it.systemProperty("$scheme.proxyHost", proxy.host)
                    it.systemProperty("$scheme.proxyPort", if (proxy.port > 0) proxy.port else 80)
                }
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
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.17")
}

// Resource-backed JVM tests package Flutter's asset directory as well. AGP 9
// needs this producer dependency explicitly; Flutter only wires the APK tasks.
tasks.configureEach {
    if (name.startsWith("package") && name.endsWith("UnitTestForUnitTest")) {
        val variant = name.removePrefix("package").removeSuffix("UnitTestForUnitTest")
        dependsOn("copyFlutterAssets$variant")
    }
}
