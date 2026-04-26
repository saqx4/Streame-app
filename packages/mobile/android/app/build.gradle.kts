plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.streame.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Enable desugaring for modern Java features (required by ota_update)
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.streame.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Enable multidex for desugaring
        multiDexEnabled = true
        
        // NDK configuration for native libraries
        ndk {
            abiFilters.addAll(listOf("armeabi-v7a", "arm64-v8a", "x86_64"))
        }
    }

    buildTypes {
        release {
            // Enable minification and resource shrinking
            isMinifyEnabled = true
            isShrinkResources = true
            
            // Use release signing config if available, otherwise fall back to debug
            signingConfig = if (project.hasProperty("STREAME_KEYSTORE_PATH")) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
    
    // Release signing configuration (uses environment variables or gradle.properties)
    signingConfigs {
        create("release") {
            storeFile = file(project.findProperty("STREAME_KEYSTORE_PATH") as String? ?: "release.keystore")
            storePassword = project.findProperty("STREAME_KEYSTORE_PASSWORD") as String? ?: ""
            keyAlias = project.findProperty("STREAME_KEY_ALIAS") as String? ?: "streame"
            keyPassword = project.findProperty("STREAME_KEY_PASSWORD") as String? ?: ""
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Core library desugaring for modern Java features
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
