package io.appbeyond.freelance.deep.auth

/**
 * The signed-in member. Email/password is the only method the server offers.
 * Ported from Deep/Deep/Features/Onboarding/Models/Account.swift, trimmed to
 * what the Android client needs — no Apple ID / keychain concerns here.
 */
data class Account(
  val id: String,
  val email: String,
  val displayName: String,
) {
  /**
   * Up to two uppercased initials from the display name's words; "·" when none.
   * Ported from `SettingsView.initials` (~line 163), which splits on the
   * literal space character and drops empty pieces (Swift's
   * `split(separator:)` default), so runs of whitespace collapse the same way.
   */
  val initials: String
    get() {
      val letters = displayName.split(" ")
        .filter { it.isNotEmpty() }
        .take(2)
        .mapNotNull { it.firstOrNull()?.uppercaseChar() }
      return if (letters.isEmpty()) "·" else letters.joinToString("")
    }

  companion object {
    /** Stands in when restore can't reach the server and nothing was cached. [resolveRestore] */
    val Placeholder = Account(id = "", email = "", displayName = "Friend")
  }
}
