import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

val missingReleaseSigningProperties =
    listOf("keyAlias", "keyPassword", "storeFile", "storePassword").filter {
        keystoreProperties.getProperty(it).isNullOrBlank()
    }
val validateReleaseSigningCredentials by tasks.registering {
    doLast {
        check(missingReleaseSigningProperties.isEmpty()) {
            "Release signing requires android/key.properties with: " +
                missingReleaseSigningProperties.joinToString(", ") +
                ". Debug builds do not require release credentials."
        }
    }
}
tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    dependsOn(validateReleaseSigningCredentials)
}

android {
    namespace = "com.tcf.take_care_refrigerator"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.tcf.take_care_refrigerator"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        resValue("string", "app_name", "냉장고를 부탁해")
        manifestPlaceholders["supabaseRedirectScheme"] = "io.supabase.flutterquickstart"
        manifestPlaceholders["kakaoRedirectScheme"] = "kakaoCONFIGURE_PUBLIC_KAKAO_APP_ID"
        manifestPlaceholders += mapOf("appAuthRedirectScheme" to "com.googleusercontent.apps.544786409936-lmq56hn6u8fhkh97ni81a84k51p29lmv")
    }

    signingConfigs {
        create("release") {
            if (missingReleaseSigningProperties.isEmpty()) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }
    
    buildTypes {
        debug {
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "냉장고를 부탁해 개발용")
            manifestPlaceholders["supabaseRedirectScheme"] = "com.tcf.take_care_refrigerator.dev"
            manifestPlaceholders["kakaoRedirectScheme"] = "com.tcf.take_care_refrigerator.dev.kakao"
            manifestPlaceholders["appAuthRedirectScheme"] = "com.tcf.take_care_refrigerator.dev.google"
        }
        release {
            // 출시용 키 사용
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
