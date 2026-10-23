import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

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
 *
 * That holds for Java 8's API only, so the module compiles against Java 8's
 * class library (`-Xjdk-release`), not the JDK 17 it runs on. Built against 17,
 * it could call later additions Android 8 doesn't have: `LocalDate.ofInstant`
 * is Java 9 but API 34 on Android, and it crashed every launch below Android 14.
 * Lint's NewApi check never sees this module, because it isn't an Android
 * module. Compiling against Java 8 turns such a call into a compile error.
 */
plugins {
  // Applied without a version on purpose. The root build file pins the Kotlin
  // Gradle Plugin on the buildscript classpath to override the one AGP bundles,
  // which puts it there with no version Gradle can reconcile against — so asking
  // for a version here fails with "already on the classpath with an unknown
  // version". The version still lives in the catalog, at that single pin.
  id("org.jetbrains.kotlin.jvm")
  // For the stores' persisted blobs (garden, practice journal, continuity
  // stamp) — local shapes this module owns. Wire DTOs still live in :app.
  alias(libs.plugins.kotlin.serialization)
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

// The shipping code only. The tests run on the JVM, never on a phone, and
// JUnit 6 itself needs 17.
tasks.named<KotlinCompile>("compileKotlin") {
  compilerOptions {
    jvmTarget.set(JvmTarget.JVM_1_8)
    freeCompilerArgs.add("-Xjdk-release=1.8")
  }
}
tasks.named<JavaCompile>("compileJava") {
  options.release.set(8)
}

dependencies {
  api(libs.kotlinx.coroutines.core)
  implementation(libs.kotlinx.serialization.json)

  testImplementation(platform(libs.junit.bom))
  testImplementation(libs.junit.jupiter)
  testImplementation(libs.kotlinx.coroutines.test)
  testImplementation(kotlin("test"))
  testRuntimeOnly(libs.junit.platform.launcher)
}

tasks.test {
  useJUnitPlatform()
}
