plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.app_ho_tro_nguoi_khiem_thi"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.app_ho_tro_nguoi_khiem_thi"
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Preserve fast model access; distribution size is reduced using ABI splits.
    androidResources {
        noCompress += listOf("tflite", "lite")
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            // Keep local release runs possible until the team configures signing.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// App dùng Interpreter CPU (4 threads). Nhánh GPU của tflite_flutter 0.11.0
// kéo vào GpuDelegate thiếu GpuDelegateFactory.Options khi R8 chạy release.
configurations.configureEach {
    exclude(group = "org.tensorflow", module = "tensorflow-lite-gpu")
}
