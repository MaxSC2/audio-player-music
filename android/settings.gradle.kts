pluginManagement {
    val flutterVersion = System.getProperty("flutter.version", "3.24.0")
    val flutterSdkPath = System.getProperty("flutter.sdkPath", "../..")
    
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.1.0" apply false
    id("org.jetbrains.kotlin.android") version "1.9.0" apply false
}

include(":app")
