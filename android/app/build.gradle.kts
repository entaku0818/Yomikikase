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

// Google公式のテスト用パブリッシャーID。このプレフィックスのIDは本番出荷禁止。
val ADMOB_TEST_PUBLISHER_ID = "ca-app-pub-3940256099942544"
val ADMOB_TEST_APP_ID = "$ADMOB_TEST_PUBLISHER_ID~3347511713"
val ADMOB_TEST_BANNER_UNIT_ID = "$ADMOB_TEST_PUBLISHER_ID/6300978111"

// defaultConfig から値を受け取り、release タスクの検証に使う
var admobIdsToValidate: Map<String, String> = emptyMap()

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

        val admobAppId = localProperties.getProperty("admob.app.id", ADMOB_TEST_APP_ID)
        val bannerUnitId = localProperties.getProperty("admob.banner.unit.id", ADMOB_TEST_BANNER_UNIT_ID)
        manifestPlaceholders["admobAppId"] = admobAppId
        buildConfigField("String", "BANNER_AD_UNIT_ID", "\"$bannerUnitId\"")

        // release ビルドでテストIDが混入していないか検証する
        // （local.properties は .gitignore 対象なので、無い環境では上のデフォルト=
        //   Googleのテスト用IDが本番AABに焼かれ、広告収益がゼロになる）
        admobIdsToValidate = mapOf(
            "admob.app.id" to admobAppId,
            "admob.banner.unit.id" to bannerUnitId,
        )
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
    testImplementation(libs.okhttp.mockwebserver)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.ui.test.junit4)
    debugImplementation(libs.androidx.ui.tooling)
    debugImplementation(libs.androidx.ui.test.manifest)
}

// release ビルド（assembleRelease / bundleRelease）の前に AdMob IDを検証し、
// Googleのテスト用IDやプレースホルダが混入していればビルドを失敗させる。
// local.properties が .gitignore 対象のため、無い環境で release を焼くと
// テストIDのAABが出来上がって広告収益がゼロになる事故を防ぐ。
val validateReleaseAdmobIds = tasks.register("validateReleaseAdmobIds") {
    group = "verification"
    description = "release ビルドに AdMob のテスト用IDが混入していないか検証する"

    val ids = admobIdsToValidate
    val testPublisher = ADMOB_TEST_PUBLISHER_ID
    val unitIdPattern = Regex("""^ca-app-pub-\d{16}/\d{10}$""")
    val appIdPattern = Regex("""^ca-app-pub-\d{16}~\d{10}$""")

    doLast {
        val problems = ids.mapNotNull { (key, value) ->
            val expectedPattern = if (key.endsWith("app.id")) appIdPattern else unitIdPattern
            when {
                value.isBlank() -> "  • $key: 未設定（空）です。"
                value.startsWith(testPublisher) -> "  • $key: Googleのテスト用IDのままです（$value）"
                !expectedPattern.matches(value) -> "  • $key: AdMob IDの書式ではありません（$value）"
                else -> null
            }
        }

        if (problems.isNotEmpty()) {
            throw GradleException(
                """
                |release ビルドに本番の AdMob ID が設定されていません。このままでは広告収益がゼロになるため、ビルドを中止しました。
                |
                |テストIDのまま／未設定の項目:
                |${problems.joinToString("\n")}
                |
                |本番IDの書き込み先:
                |  android/local.properties （.gitignore 対象。無ければ作成する）
                |    admob.app.id=ca-app-pub-3484697221349891~4288708336
                |    admob.banner.unit.id=ca-app-pub-3484697221349891/XXXXXXXXXX
                |
                |本番IDは AdMob 管理画面 > アプリ「読み上げナレーター」
                |(ca-app-pub-3484697221349891~4288708336) > 広告ユニット から取得できます。
                """.trimMargin()
            )
        }
        logger.lifecycle("AdMob ID validation: OK (${ids.size} 項目)")
    }
}

tasks.matching { it.name == "assembleRelease" || it.name == "bundleRelease" }.configureEach {
    dependsOn(validateReleaseAdmobIds)
}
