package io.appbeyond.freelance.deep.shared.localization

/**
 * The language DEEP reads its copy in.
 *
 * Ported from `Deep/Deep/Shared/Localization/AppLanguage.swift`, minus the pieces
 * that have no Android counterpart yet. DEEP matches the device by default —
 * that is behaviour, not a setting, so there is no "follow the system" case to
 * pick. Choosing one of these pins it in-app, so a member whose phone is set to
 * English can still read DEEP in Thai without changing anything about their
 * phone.
 *
 * That distinction is the whole reason `Accept-Language` is built from this enum
 * rather than from the system locale: server-authored copy — track and collection
 * titles, plant names, the pause's welcome lines — must arrive in the language
 * the member picked in-app.
 *
 * The choice is persisted and applied by [LanguageStore]. iOS's `Locale.app` /
 * `Bundle.app` ambient projections have no counterpart: the per-app locale puts
 * the choice into every context's configuration, so resources and
 * [rememberAppLocale] already read in it.
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
  }
}
