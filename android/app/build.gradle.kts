import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.ksp)
}

val localProperties = Properties().apply {
    val f = rootProject.file("local.properties")
    if (f.exists()) load(f.inputStream())
}

android {
    namespace = "com.entaku.VoiceYourText"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.entaku.VoiceYourText"
        minSdk = 30
        targetSdk = 36
        versionCode = 4
        versionName = "1.1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        val admobAppId = localProperties.getProperty("admob.app.id", "ca-app-pub-3940256099942544~3347511713")
        val bannerUnitId = localProperties.getProperty("admob.banner.unit.id", "ca-app-pub-3940256099942544/6300978111")
        manifestPlaceholders["admobAppId"] = admobAppId
        buildConfigField("String", "BANNER_AD_UNIT_ID", "\"$bannerUnitId\"")
    }

    val releaseKeystoreFile = file("voiceyourtext-release.jks")
    if (releaseKeystoreFile.exists()) {
        signingConfigs {
            create("release") {
                storeFile = releaseKeystoreFile
                storePassword = localProperties.getProperty("keystore.store.password")
                keyAlias = localProperties.getProperty("keystore.key.alias")
                keyPassword = localProperties.getProperty("keystore.key.password")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            if (releaseKeystoreFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions {
        jvmTarget = "11"
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
    lint {
        // 既存コードの指摘は baseline に凍結し、新規エラーのみ CI で落とす
        baseline = file("lint-baseline.xml")
    }
}

dependencies {

    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.ui)
    implementation(libs.androidx.ui.graphics)
    implementation(libs.androidx.ui.tooling.preview)
    implementation(libs.androidx.material3)
    implementation(libs.androidx.material.icons.extended)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.media)
    implementation(libs.play.services.ads)
    implementation(libs.androidx.room.runtime)
    implementation(libs.androidx.room.ktx)
    ksp(libs.androidx.room.compiler)
    implementation(libs.okhttp)
    implementation(libs.jsoup)
    testImplementation(libs.junit)
    testImplementation(libs.mockito.core)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.ui.test.junit4)
    debugImplementation(libs.androidx.ui.tooling)
    debugImplementation(libs.androidx.ui.test.manifest)
}