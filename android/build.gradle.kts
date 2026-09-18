// AGP 9 has built-in Kotlin support and would otherwise silently use the compiler
// it bundles (2.2.10). That compiler cannot read this dependency set: Compose
// 1.12 and Coil 3.6 are built against Kotlin 2.4, whose metadata version 2.4.0 is
// beyond what a 2.2 compiler accepts, and the build fails on `kotlin.Unit` itself.
//
// Pinning the Kotlin Gradle Plugin on the buildscript classpath is the documented
// way to override the bundled version. The version lives in the catalog like
// every other.
buildscript {
  dependencies {
    classpath(libs.kotlin.gradle.plugin)
  }
}

// Plugins are declared here without applying them, so each module opts in and the
// version lives only in gradle/libs.versions.toml.
plugins {
  alias(libs.plugins.android.application) apply false
  alias(libs.plugins.kotlin.compose) apply false
  alias(libs.plugins.kotlin.serialization) apply false
}
