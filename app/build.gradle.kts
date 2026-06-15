plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.hilt)
    alias(libs.plugins.ksp)
}

android {
    namespace   = "com.fastpos.android"
    compileSdk  = 35

    defaultConfig {
        applicationId  = "com.fastpos.android"
        minSdk = 24
        targetSdk      = 35
        versionCode    = 3
        versionName    = "25.1.1"

        buildConfigField("String", "GITHUB_UPDATE_OWNER", "\"zeeshan47\"")
        buildConfigField("String", "GITHUB_UPDATE_REPO", "\"andriodmealflow\"")
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions { jvmTarget = "17" }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
            excludes += "META-INF/LICENSE*"
        }
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.activity.compose)

    // Compose BOM
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.ui.graphics)
    implementation(libs.compose.ui.tooling.preview)
    implementation(libs.compose.material3)
    implementation(libs.compose.material.icons.extended)
    debugImplementation(libs.compose.ui.tooling)

    // Navigation
    implementation(libs.navigation.compose)

    // Hilt
    implementation(libs.hilt.android)
    ksp(libs.hilt.compiler)
    implementation(libs.hilt.navigation.compose)

    // Coroutines
    implementation(libs.coroutines.android)

    // DataStore (persist DB connection settings)
    implementation(libs.datastore.preferences)

    // Gson
    implementation(libs.gson)

    // JTDS – SQL Server JDBC driver for direct network connection
    implementation(libs.jtds)

    // Room – local SQLite cache for offline mode
    implementation(libs.room.runtime)
    implementation(libs.room.ktx)
    ksp(libs.room.compiler)

    // ZXing – QR code generation for Raast payment QR
    implementation(libs.zxing.core)

    // Unit tests (LicenseKeyGenerator runs as a local JVM test)
    testImplementation(libs.junit)
}
