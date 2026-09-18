package io.appbeyond.freelance.deep.config

import io.appbeyond.freelance.deep.BuildConfig

/**
 * The build environment this app was compiled for, backed by the `APP_ENV`
 * BuildConfig field that each product flavor sets.
 */
enum class AppEnvironment(val rawValue: String) {
  Dev("dev"),
  Staging("staging"),
  Pilot("pilot"),
  Prod("prod");

  /** Human label for diagnostics and a debug badge. */
  val label: String
    get() = when (this) {
      Dev -> "Dev"
      Staging -> "Staging"
      Pilot -> "Pilot"
      Prod -> "Prod"
    }

  companion object {
    /**
     * Resolves a raw `APP_ENV` value, **throwing** on anything unrecognised.
     *
     * iOS falls back to `.dev` here, and both Staging.xcconfig and
     * CentralFlight.xcconfig carry warnings that a typo therefore silently
     * downgrades a shipping build to the dev environment — pointing a release at
     * a development server with no sign anything is wrong. A build failure is the
     * better outcome, and on Android the value is a compile-time constant, so
     * failing loudly here costs nothing a correct build would have paid.
     */
    fun of(rawValue: String): AppEnvironment =
      entries.firstOrNull { it.rawValue == rawValue }
        ?: error(
          "Unknown APP_ENV '$rawValue'. It must be one of " +
            entries.joinToString(", ") { it.rawValue } +
            ". Check the product flavors in app/build.gradle.kts."
        )
  }
}

/**
 * Read-only, typed projection of the per-environment build configuration.
 *
 * Values arrive from the active product flavor's BuildConfig fields and are read
 * once. This mirrors the design-token pattern: one source of truth, surfaced as
 * first-class typed values — never `BuildConfig.SOMETHING` scattered across call
 * sites.
 */
object AppConfig {
  val environment: AppEnvironment = AppEnvironment.of(BuildConfig.APP_ENV)

  /** Always without a trailing slash, so callers can append a leading-slash path. */
  val apiBaseUrl: String = BuildConfig.API_BASE_URL.trim().trimEnd('/')

  /** True only for the local dev build — used to surface debug affordances. */
  val isDev: Boolean get() = environment == AppEnvironment.Dev

  val versionName: String = BuildConfig.VERSION_NAME
  val versionCode: Int = BuildConfig.VERSION_CODE
}
