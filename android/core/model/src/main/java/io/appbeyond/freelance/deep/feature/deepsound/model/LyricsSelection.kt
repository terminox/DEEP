package io.appbeyond.freelance.deep.feature.deepsound.model

/** One track's lyrics in a single language. */
data class TrackLyrics(val languageCode: String, val content: String)

/**
 * Ported from Deep/Deep/Features/DeepSound/Components/LyricsSheet.swift's
 * `current` computed property and its language-picker visibility check.
 */
object LyricsSelection {
  /** The lyrics to show: the ones matching [selectedLanguage] if any, else
   * the first the track has, else nothing — an empty [lyrics] list is the
   * calm empty state, not an error. */
  fun select(lyrics: List<TrackLyrics>, selectedLanguage: String?): TrackLyrics? =
    lyrics.firstOrNull { it.languageCode == selectedLanguage } ?: lyrics.firstOrNull()

  /** The language switcher only earns its place once there's an actual
   * choice to make. */
  fun showsLanguagePicker(lyrics: List<TrackLyrics>): Boolean = lyrics.size > 1
}
