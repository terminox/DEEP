import java.util.Properties

plugins {
  alias(libs.plugins.android.application)
  alias(libs.plugins.kotlin.compose)
  alias(libs.plugins.kotlin.serialization)
}

// The Mac's host for a Dev build, mirroring Deep/Config/Local.xcconfig on iOS.
//
// Two cases iOS never had to cover. The emulator cannot resolve an mDNS `.local`
// name and reaches the host machine at 10.0.2.2, while a physical device on the
// same Wi-Fi resolves the mDNS name and cannot reach 10.0.2.2. So the default is
// the emulator's loopback, and `scripts/dev-setup.sh` writes the mDNS name into
// android/local.properties (gitignored) for device builds.
//
// Read through a Provider rather than with a plain file read so the value stays a
// declared build input.
val devApiHost: String =
  providers.fileContents(layout.settingsDirectory.file("local.properties")).asText.orNull
    ?.let { text -> Properties().apply { load(text.reader()) }.getProperty("deep.devApiHost") }
    ?.trim()
    ?.takeIf { it.isNotEmpty() }
    ?: "10.0.2.2:8080"

// Staging and Pilot deliberately share production's Cloud Run service, exactly as
// Deep/Config/Staging.xcconfig and Pilot.xcconfig do: neither staging-api.deep.app
// nor pilot-api.deep.app was ever stood up. Splitting them later is a one-line
// change per flavor.
val cloudRunApi = "https://deep-api-157102552469.asia-southeast1.run.app"

// Release signing, read from a gitignored keystore.properties.
//
// Absent — which it is on a fresh clone, and on any machine but the one holding
// the key — the release build falls back to the debug signing config so it still
// produces an installable APK. That graceful absence is the same trick
// Dev.xcconfig plays with `#include? "Local.xcconfig"`.
//
// terminox/DEEP is a public repository, so neither the keystore nor this
// properties file may ever enter the tree. Both are gitignored.
val keystore: Properties? =
  providers.fileContents(layout.settingsDirectory.file("keystore.properties")).asText.orNull
    ?.let { text -> Properties().apply { load(text.reader()) } }

android {
  namespace = "io.appbeyond.freelance.deep"

  // 37, not 36, because Compose 1.12 and Coil 3.6 both declare that dependents
  // must compile against it. Compiling against 37 does not opt into Android 17's
  // behaviour changes — targetSdk does, and that stays at 36, which is also what
  // Play has required of new apps since 31 August 2026.
  compileSdk = 37

  defaultConfig {
    applicationId = "io.appbeyond.freelance.deep"
    minSdk = 26
    targetSdk = 36

    // Week two of eight. The versionCode scheme is still open — iOS stamps Unix
    // epoch seconds, which does not survive the port because versionCode is a
    // signed 32-bit int that can never decrease on a store track.
    versionCode = 2
    versionName = "0.0.2"

    testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
  }

  // One dimension, four environments — the Gradle shape of the xcconfig chain in
  // Deep/Config. applicationIdSuffix mirrors BUNDLE_ID_SUFFIX so all four builds
  // sit on one device at once.
  flavorDimensions += "environment"

  productFlavors {
    create("dev") {
      dimension = "environment"
      applicationIdSuffix = ".dev"
      buildConfigField("String", "APP_ENV", "\"dev\"")
      buildConfigField("String", "API_BASE_URL", "\"http://$devApiHost\"")
      resValue("string", "app_name", "DEEP Dev")
    }
    create("staging") {
      dimension = "environment"
      applicationIdSuffix = ".staging"
      buildConfigField("String", "APP_ENV", "\"staging\"")
      buildConfigField("String", "API_BASE_URL", "\"$cloudRunApi\"")
      resValue("string", "app_name", "DEEP Staging")
    }
    create("pilot") {
      dimension = "environment"
      applicationIdSuffix = ".pilot"
      buildConfigField("String", "APP_ENV", "\"pilot\"")
      buildConfigField("String", "API_BASE_URL", "\"$cloudRunApi\"")
      resValue("string", "app_name", "DEEP Pilot")
    }
    create("prod") {
      dimension = "environment"
      buildConfigField("String", "APP_ENV", "\"prod\"")
      buildConfigField("String", "API_BASE_URL", "\"$cloudRunApi\"")
      resValue("string", "app_name", "DEEP")
    }
  }

  signingConfigs {
    if (keystore != null) {
      create("release") {
        storeFile = rootProject.file(keystore.getProperty("storeFile"))
        storePassword = keystore.getProperty("storePassword")
        keyAlias = keystore.getProperty("keyAlias")
        keyPassword = keystore.getProperty("keyPassword")
      }
    }
  }

  buildTypes {
    debug {
      isMinifyEnabled = false
    }
    release {
      isMinifyEnabled = true
      isShrinkResources = true
      proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
      signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
    }
  }

  buildFeatures {
    compose = true
    // Both are off by default in AGP 9 and must be opted into. buildConfig backs
    // APP_ENV and API_BASE_URL; resValues backs the per-flavor app_name, which is
    // how DEEP Dev and DEEP Staging tell themselves apart on the launcher.
    buildConfig = true
    resValues = true
  }

  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
  }

  packaging {
    resources.excludes += "/META-INF/{AL2.0,LGPL2.1}"
  }
}

// AGP 9 has built-in Kotlin support, so kotlinOptions inside `android` is gone and
// this top-level block is where the compiler is configured. jvmTarget is inherited
// from android.compileOptions.targetCompatibility and must not be set again.
kotlin {
  compilerOptions {
    freeCompilerArgs.add("-Xjvm-default=all")
  }
}

// The Android twin of the "Check dev API host" build phase in the Xcode project.
//
// Same philosophy: fail at build time with the fix in the message, rather than
// install an app whose every request times out. The iOS phase catches a Dev build
// for a device still pointing at localhost. The equivalent mistakes here are a
// shipping flavor pointing at a dev host, and a dev flavor with no host at all.
// A typed task with declared inputs rather than a `doLast` closure. A closure in
// a Kotlin build script captures the script object itself, which the
// configuration cache cannot serialise; properties set at configuration time and
// read in a @TaskAction carry only the values.
abstract class CheckApiHosts : DefaultTask() {

  @get:Input
  abstract val devUrl: Property<String>

  @get:Input
  abstract val shippingUrl: Property<String>

  @TaskAction
  fun check() {
    val dev = devUrl.get()
    val shipping = shippingUrl.get()
    val problems = mutableListOf<String>()

    if (dev.removePrefix("http://").isEmpty()) {
      problems += "The dev flavor has no API host."
    }
    if (dev.contains("localhost") || dev.contains("127.0.0.1")) {
      problems +=
        "dev points at $dev, which neither the emulator nor a device can reach. " +
          "The emulator needs 10.0.2.2; a physical device needs this Mac's " +
          "address. Run ./scripts/dev-setup.sh from the repo root, then build again."
    }
    if (!shipping.startsWith("https://")) {
      problems +=
        "staging, pilot and prod point at $shipping, which is not https. A " +
          "shipping build must not use cleartext; only the dev flavor may."
    }

    if (problems.isNotEmpty()) {
      throw GradleException(
        "Build environment misconfigured:\n" + problems.joinToString("\n") { "  - $it" }
      )
    }
  }
}

val checkApiHosts = tasks.register<CheckApiHosts>("checkApiHosts") {
  group = "verification"
  description = "Fails if any flavor's API base URL is unusable for that environment."
  devUrl.set("http://$devApiHost")
  shippingUrl.set(cloudRunApi)
}

tasks.named("preBuild") { dependsOn(checkApiHosts) }

dependencies {
  // The pure-logic module: breath engine, garden growth, practice arithmetic,
  // the reminder schedule, continent ordering, and the token refresher. No
  // Android dependency, so its tests run on plain JUnit Platform in a second.
  implementation(project(":core:model"))

  implementation(platform(libs.androidx.compose.bom))

  implementation(libs.androidx.core.ktx)
  implementation(libs.androidx.core.splashscreen)
  implementation(libs.androidx.activity.compose)
  implementation(libs.androidx.navigation.compose)
  implementation(libs.androidx.lifecycle.runtime.ktx)
  implementation(libs.androidx.lifecycle.runtime.compose)

  implementation(libs.androidx.compose.ui)
  implementation(libs.androidx.compose.ui.graphics)
  implementation(libs.androidx.compose.foundation)
  implementation(libs.androidx.compose.material3)
  implementation(libs.androidx.compose.ui.tooling.preview)
  debugImplementation(libs.androidx.compose.ui.tooling)

  implementation(libs.okhttp)
  implementation(libs.okhttp.logging)
  implementation(libs.retrofit)
  implementation(libs.retrofit.serialization)
  implementation(libs.kotlinx.serialization.json)
  implementation(libs.kotlinx.coroutines.android)

  implementation(libs.androidx.datastore.preferences)

  // Week 3 is when audio lands, but the home hero plays looping video in week 1
  // and that is the same player.
  implementation(libs.androidx.media3.exoplayer)

  implementation(libs.coil.compose)
  implementation(libs.coil.network.okhttp)
}
