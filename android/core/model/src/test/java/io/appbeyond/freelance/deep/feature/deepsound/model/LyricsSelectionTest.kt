package io.appbeyond.freelance.deep.feature.deepsound.model

import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** Ported from Deep/Deep/Features/DeepSound/Components/LyricsSheet.swift's
 * `current` computed property and its language-picker visibility check. */
class LyricsSelectionTest {
  private val english = TrackLyrics(languageCode = "en", content = "English words")
  private val thai = TrackLyrics(languageCode = "th", content = "Thai words")

  // MARK: - select

  @Test
  @DisplayName("selects the lyrics matching the chosen language")
  fun selectsTheMatchingLanguage() {
    val result = LyricsSelection.select(listOf(english, thai), selectedLanguage = "th")
    assertEquals(thai, result)
  }

  @Test
  @DisplayName("falls back to the first language when none is selected")
  fun fallsBackToFirstWhenNoneSelected() {
    val result = LyricsSelection.select(listOf(english, thai), selectedLanguage = null)
    assertEquals(english, result)
  }

  @Test
  @DisplayName("falls back to the first language when the selection doesn't match anything")
  fun fallsBackToFirstWhenSelectionIsUnknown() {
    val result = LyricsSelection.select(listOf(english, thai), selectedLanguage = "fr")
    assertEquals(english, result)
  }

  @Test
  @DisplayName("an empty lyrics list selects nothing")
  fun emptyListSelectsNothing() {
    val result = LyricsSelection.select(emptyList(), selectedLanguage = "en")
    assertNull(result)
  }

  // MARK: - showsLanguagePicker

  @Test
  @DisplayName("the language picker only shows once there's an actual choice")
  fun pickerShowsOnlyWithMultipleLanguages() {
    assertTrue(LyricsSelection.showsLanguagePicker(listOf(english, thai)))
    assertFalse(LyricsSelection.showsLanguagePicker(listOf(english)))
    assertFalse(LyricsSelection.showsLanguagePicker(emptyList()))
  }
}
