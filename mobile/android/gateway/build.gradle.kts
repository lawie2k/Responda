plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.responda.gateway"
    compileSdk = 36
    defaultConfig {
        applicationId = "com.responda.gateway"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "1.0.0"
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    buildFeatures { buildConfig = true }
}
kotlin { compilerOptions { jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17 } }
dependencies {
    implementation("androidx.work:work-runtime-ktx:2.12.0")
    testImplementation("junit:junit:4.13.2")
}
