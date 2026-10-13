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
 *   is read back at launch and adopted here, so the two never disagree.
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

  /** Reads the stored choice and reconciles it with the system's per-app setting. */
  fun load() {
    val stored = runBlocking { runCatching { blob.read() }.getOrNull() }?.let(AppLanguage::of)
    val system = systemPerAppLanguage()
    _selection.value = when {
      // Chosen in the system's per-app language settings while DEEP slept.
      system != null -> system.also { if (it != stored) persist(it) }
      stored != null -> stored.also { applySystemLocale(it) }
      else -> deviceMatched(context)
    }
  }

  /**
   * Adopts a language. The write happens even when the language is already
   * the one being read, because until now it was only *matching* the device;
   * picking it pins it, so a member who later switches their phone's language
   * keeps reading DEEP in the one they chose.
   */
  fun select(language: AppLanguage) {
    persist(language)
    applySystemLocale(language)
    _selection.value = language
  }

  /** [base] re-configured to read in the current selection — for contexts the
   * per-app locale doesn't reach below API 33 (the activity, the receiver). */
  fun localized(base: Context): Context = localized(base, _selection.value)

  private fun persist(language: AppLanguage) {
    scope.launch { runCatching { blob.write(language.rawValue) } }
  }

  private fun applySystemLocale(language: AppLanguage) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
    val manager = context.getSystemService(LocaleManager::class.java) ?: return
    val wanted = LocaleList.forLanguageTags(language.localeIdentifier)
    if (manager.applicationLocales != wanted) manager.applicationLocales = wanted
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
