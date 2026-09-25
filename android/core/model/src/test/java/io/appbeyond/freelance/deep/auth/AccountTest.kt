package io.appbeyond.freelance.deep.auth

import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals

/** Ported from `SettingsView.initials` (~line 163). */
class AccountTest {

  private fun account(displayName: String) = Account(id = "1", email = "mali@example.com", displayName = displayName)

  @Test
  @DisplayName("two words become two uppercased initials")
  fun twoWords() {
    assertEquals("MS", account("Mali Suda").initials)
  }

  @Test
  @DisplayName("one word becomes one uppercased initial")
  fun oneWord() {
    assertEquals("M", account("mali").initials)
  }

  @Test
  @DisplayName("whitespace-only name has no words, so it falls back to the middle dot")
  fun blank() {
    assertEquals("·", account("  ").initials)
  }

  @Test
  @DisplayName("three or more words only take the first two")
  fun threeWords() {
    assertEquals("AB", account("Anong Bella Chai").initials)
  }
}
