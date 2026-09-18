import org.jetbrains.kotlin.gradle.dsl.JvmTarget

/*
 * A plain Kotlin/JVM module with no Android dependency at all.
 *
 * This is where the app's pure logic lives — the breath engine, garden growth,
 * practice arithmetic, the reminder schedule, continent ordering — which is also
 * where almost all of the iOS test suite's value sits: about fifteen of its
 * twenty-one suites are platform-free.
 *
 * Keeping them out of the Android module is what makes them cheap. They run
 * straight on JUnit Platform in about a second, with no Robolectric, no
 * instrumentation, no emulator, and none of AGP's variant-aware test machinery.
 * Over eight weeks of weekly releases, that is the difference between a parity
 * harness you actually run and one you stop running.
 *
 * minSdk is 26, so java.time is available natively on device and no core-library
 * desugaring is needed for anything written here to behave identically in both
 * places.
 */
plugins {
  // Applied without a version on purpose. The root build file pins the Kotlin
  // Gradle Plugin on the buildscript classpath to override the one AGP bundles,
  // which puts it there with no version Gradle can reconcile against — so asking
  // for a version here fails with "already on the classpath with an unknown
  // version". The version still lives in the catalog, at that single pin.
  id("org.jetbrains.kotlin.jvm")
}

java {
  sourceCompatibility = JavaVersion.VERSION_17
  targetCompatibility = JavaVersion.VERSION_17
}

kotlin {
  compilerOptions {
    jvmTarget.set(JvmTarget.JVM_17)
  }
}

dependencies {
  api(libs.kotlinx.coroutines.core)

  testImplementation(platform(libs.junit.bom))
  testImplementation(libs.junit.jupiter)
  testImplementation(libs.kotlinx.coroutines.test)
  testImplementation(kotlin("test"))
  testRuntimeOnly(libs.junit.platform.launcher)
}

tasks.test {
  useJUnitPlatform()
}
