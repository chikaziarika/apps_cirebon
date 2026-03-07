import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.frontend"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    defaultConfig {
        applicationId = "com.example.frontend"
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // Kita ambil nilainya satu per satu
            val alias = keystoreProperties.getProperty("keyAlias")
            val pass = keystoreProperties.getProperty("storePassword")
            val keyPass = keystoreProperties.getProperty("keyPassword")
            val fileJks = keystoreProperties.getProperty("storeFile")

            if (alias != null && pass != null && fileJks != null) {
                keyAlias = alias
                storePassword = pass
                keyPassword = keyPass ?: pass // Jika keyPassword kosong, pakai storePassword
                
                // Paksa arahkan ke folder app
                storeFile = file(project.projectDir.resolve(fileJks))
                
                println("✅ JKS Ditemukan di: ${storeFile?.absolutePath}")
            } else {
                println("❌ Data di key.properties tidak lengkap!")
            }
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}