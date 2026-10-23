package io.appbeyond.freelance.deep.shared.localization

import android.app.LocaleManager
import android.content.Context
import android.content.res.Configuration
import android.content.res.Resources
import android.os.Build
import android.os.LocaleList
import io.appbeyond.freelance.deep.shared.persistence.BlobStoring
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import java.util.Locale

/**
 * The member's language choice, and the one thing that changes it.
 *
 * Ported from Deep/Deep/Shared/Localization/LanguageStore.swift. A single raw
 * value in its own DataStore file (`deep.language`) — deliberately *not*
 * account state, so it survives logging out: the language you read in belongs
 * to the phone in your hand, not to the account signed into it. Nothing stored
 * means nobody has chosen, and DEEP follows the device.
 *
 * **Applying it.** The per-app locale API, without AppCompat (the app has no
 * AppCompat activity or theme to hang `setApplicationLocales` on):
 * - **API 33+:** [LocaleManager.setApplicationLocales]. The system persists
 *   it, recreates the activity, and lists DEEP's languages in its own
 *   per-app language settings (`generateLocaleConfig`). A choice made there
 *   is read back at launch ([load]) and whenever the activity is created or
 *   the reminder posts ([adoptSystemChoice]), so the two never disagree.
 * - **API 26–32:** `MainActivity` wraps its base context in [localized] and
 *   recreates itself when [selection] changes; [localized] also serves the
 *   reminder receiver, which posts outside any activity.
 *
 * Copy is resolved from that configuration everywhere, and `Accept-Language`
 * reads [selection] per request (`DeepHttp`), so server-authored content
 * follows too once the screens refetch.
 *
 * The stored value is read once, synchronously, as the process starts
 * ([load]) — `MainActivity.attachBaseContext` needs it before the first frame,
 * and a one-key Preferences file is a few milliseconds. AppCompat's own
 * `autoStoreLocales` does the same synchronous read.
 */
class LanguageStore(
  private val context: Context,
  private val blob: BlobStoring,
  private val scope: CoroutineScope,
) {

  private val _selection = MutableStateFlow(deviceMatched(context))

  /** The language DEEP reads in: the pinned choice, or the device's. */
  val selection: StateFlow<AppLanguage> = _selection.asStateFlow()

  /**
   * Whether a language has been chosen — in DEEP's picker or the system's
   * per-app settings — rather than only matched to the device. Until it has,
   * [selection] follows the device ([adoptSystemChoice]).
   */
  private var pinned = false

  /** Reads the stored choice and reconciles it with the system's per-app setting. */
  fun load() {
    val stored = runBlocking { runCatching { blob.read() }.getOrNull() }?.let(AppLanguage::of)
    val system = systemPerAppLanguage()
    pinned = system != null || stored != null
    _selection.value = when {
      // Chosen in the system's per-app language settings while DEEP slept.
      system != null -> system.also { if (it != stored) persist(it) }
      stored != null -> stored.also { applySystemLocale(it) }
      else -> deviceMatched(context)
    }
    applyProcessLocale(_selection.value)
  }

  /**
   * Adopts a language. The write happens even when the language is already
   * the one being read, because until now it was only *matching* the device;
   * picking it pins it, so a member who later switches their phone's language
   * keeps reading DEEP in the one they chose.
   */
  fun select(language: AppLanguage) {
    pinned = true
    persist(language)
    applySystemLocale(language)
    // Ahead of the selection, which below API 33 is what recreates the
    // activity: the new one formats in the new language from its first frame.
    applyProcessLocale(language)
    _selection.value = language
  }

  /**
   * Adopts a language picked in the system's per-app language settings while
   * DEEP's process was alive. That change recreates the activity (so the UI
   * reads in it at once) but never re-runs [load], so the selection — which
   * drives the reminder's copy and `Accept-Language` — kept the old one (QA
   * round 1, B7). `MainActivity` calls this as it is created; [localized]
   * calls it before the reminder posts.
   *
   * With nothing chosen anywhere, it re-matches the device instead: from
   * API 33 a device language change reaches the running activity as a
   * configuration change (`MainActivity.onConfigurationChanged`), and the
   * screens follow it — so the selection must too, or `Accept-Language`, the
   * reminder and the notification channels stay in the language the process
   * started in. That match is never persisted: it is not a choice. Both paths
   * write only when the language actually changed, so a configuration change
   * that leaves it alone (a font size, a rotation) touches nothing.
   */
  fun adoptSystemChoice() {
    val system = systemPerAppLanguage()
    if (system == null) {
      if (!pinned) {
        val device = deviceMatched(context)
        if (device != _selection.value) _selection.value = device
      }
      return
    }
    pinned = true
    if (system == _selection.value) return
    persist(system)
    _selection.value = system
  }

  /** [base] re-configured to read in the language DEEP reads in now — for
   * contexts the per-app locale doesn't reach below API 33 (the activity), and
   * the reminder receiver, which posts outside any activity. */
  fun localized(base: Context): Context {
    adoptSystemChoice()
    applyProcessLocale(_selection.value)
    return localized(base, _selection.value)
  }

  private fun persist(language: AppLanguage) {
    scope.launch { runCatching { blob.write(language.rawValue) } }
  }

  private fun applySystemLocale(language: AppLanguage) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
    val manager = context.getSystemService(LocaleManager::class.java) ?: return
    val wanted = LocaleList.forLanguageTags(language.localeIdentifier)
    if (manager.applicationLocales != wanted) manager.applicationLocales = wanted
  }

  /**
   * Below API 33, makes the process's default locale read in [language] too.
   * The wrapped base context ([localized]) reaches resources only; everything
   * formatted through `Locale.getDefault()` — `DateUtils`' relative dates on
   * the peace messages, a `NumberFormat` given no locale — stayed English on
   * Thai screens. From 33 the per-app locale already sets the default, so this
   * matches it there and does nothing itself.
   *
   * Left alone when the default already speaks [language], so a device in
   * en-GB keeps its region rather than being narrowed to DEEP's bare tag.
   * (Every date DEEP keys or parses is ISO `java.time` and every machine
   * format pins `Locale.ROOT`/`US`, so th_TH's Buddhist calendar can't shift
   * them.)
   */
  private fun applyProcessLocale(language: AppLanguage) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) return
    if (Locale.getDefault().language == language.resourceLanguageCode) return
    Locale.setDefault(Locale.forLanguageTag(language.localeIdentifier))
  }

  private fun systemPerAppLanguage(): AppLanguage? {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return null
    val locales = context.getSystemService(LocaleManager::class.java)?.applicationLocales ?: return null
    if (locales.isEmpty) return null
    return languageOf(locales.get(0))
  }

  companion object {

    /**
     * The device's language narrowed to the two DEEP speaks — the system
     * locale itself, not the process default, which on API 33+ already
     * carries DEEP's own override.
     */
    fun deviceMatched(context: Context): AppLanguage {
      val locale = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        context.getSystemService(LocaleManager::class.java)?.systemLocales?.takeIf { !it.isEmpty }?.get(0)
      } else {
        null
      } ?: Resources.getSystem().configuration.locales.get(0)
      return languageOf(locale)
    }

    /** [base] configured to read in [language]. */
    fun localized(base: Context, language: AppLanguage): Context {
      val locale = Locale.forLanguageTag(language.localeIdentifier)
      val configuration = Configuration(base.resources.configuration).apply { setLocales(LocaleList(locale)) }
      return base.createConfigurationContext(configuration)
    }

    private fun languageOf(locale: Locale?): AppLanguage =
      if (locale?.language == AppLanguage.Thai.resourceLanguageCode) AppLanguage.Thai else AppLanguage.English
  }
}
