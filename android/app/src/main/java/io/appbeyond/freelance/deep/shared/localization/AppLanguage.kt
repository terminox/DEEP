package io.appbeyond.freelance.deep.shared.localization

import java.util.Locale

/**
 * The language Deep reads its copy in.
 *
 * Ported from `Deep/Deep/Shared/Localization/AppLanguage.swift`, minus the pieces
 * that have no Android counterpart yet. Deep matches the device by default —
 * that is behaviour, not a setting, so there is no "follow the system" case to
 * pick. Choosing one of these pins it in-app, so a member whose phone is set to
 * English can still read Deep in Thai without changing anything about their
 * phone.
 *
 * That distinction is the whole reason `Accept-Language` is built from this enum
 * rather than from the system locale: server-authored copy — track and collection
 * titles, plant names, the pause's welcome lines — must arrive in the language
 * the member picked in-app.
 *
 * Not ported (yet): the persisted choice (`LanguageStore`), and the `Locale.app`
 * / `Bundle.app` ambient projections that resolve copy outside the view tree.
 * Until a store lands, [AppDependencies][io.appbeyond.freelance.deep.networking.AppDependencies]
 * holds the choice in memory, seeded from [deviceMatched].
 */
enum class AppLanguage(val rawValue: String) {
  English("english"),
  Thai("thai");

  /** BCP-47 identifier for formatting dates, numbers and lists. */
  val localeIdentifier: String
    get() = when (this) {
      English -> "en-US"
      Thai -> "th"
    }

  /**
   * The `Accept-Language` header this language should send.
   *
   * BCP-47 with hyphens, which is what the header wants — a `java.util.Locale`
   * is not a substitute, since `toString()` renders as `en_US`.
   */
  val acceptLanguageHeader: String
    get() = localeIdentifier

  /** The `values-xx` qualifier this language's copy compiles into. */
  val resourceLanguageCode: String
    get() = when (this) {
      English -> "en"
      Thai -> "th"
    }

  /**
   * The language's name in its own language — the one label that reads right
   * whichever language the picker happens to be showing, and the reason neither
   * of these is a string resource.
   */
  val endonym: String
    get() = when (this) {
      English -> "English"
      Thai -> "ไทย"
    }

  companion object {

    /** Resolves a persisted raw value, or null if it is not one of ours. */
    fun of(rawValue: String): AppLanguage? = entries.firstOrNull { it.rawValue == rawValue }

    /**
     * The language the device is asking for, narrowed to the two Deep speaks.
     *
     * `Locale.getDefault()` already reflects a per-app language override on
     * API 33+, and the device language below that, so a phone set to French
     * lands on English without a case for it here — the same answer iOS gets
     * from `Bundle.main.preferredLocalizations`.
     */
    fun deviceMatched(): AppLanguage =
      if (Locale.getDefault().language == Thai.resourceLanguageCode) Thai else English
  }
}
