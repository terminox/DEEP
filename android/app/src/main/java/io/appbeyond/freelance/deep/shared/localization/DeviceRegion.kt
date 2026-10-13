package io.appbeyond.freelance.deep.shared.localization

import android.app.LocaleManager
import android.content.Context
import android.content.res.Resources
import android.os.Build
import android.os.LocaleList
import io.appbeyond.freelance.deep.feature.globalpause.model.PauseCountry

/**
 * Where the phone is: the device's region, never the language DEEP reads in.
 *
 * iOS reads `Locale.current.region`, which is the device's region setting
 * whatever the app's language. Android has no separate region setting; the
 * region rides the system locale list. From API 33 the per-app language is
 * applied to the process configuration (`Resources.getSystem()` included), so
 * a member reading DEEP in Thai saw the bare `th` locale and lost their
 * country from heartbeats and peace messages (QA round 2, B21). The device's
 * own list comes from [LocaleManager.getSystemLocales] there; below 33 DEEP's
 * language is applied only to its own contexts, so the system configuration
 * still holds the device list.
 *
 * The first locale in that list carrying a valid ISO-3166 alpha-2 country
 * wins ([PauseCountry.normalize]), so a device list like `th, en-US` still
 * places the member.
 */
object DeviceRegion {

  /** The device's region as an uppercase ISO alpha-2 code, or null. */
  fun isoCode(context: Context): String? {
    val locales = deviceLocales(context)
    for (index in 0 until locales.size()) {
      PauseCountry.normalize(locales.get(index).country)?.let { return it }
    }
    return null
  }

  private fun deviceLocales(context: Context): LocaleList {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      context.getSystemService(LocaleManager::class.java)?.systemLocales
        ?.takeIf { !it.isEmpty }
        ?.let { return it }
    }
    return Resources.getSystem().configuration.locales
  }
}
