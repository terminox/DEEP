package io.appbeyond.freelance.deep.feature.premium.model

/**
 * Which door the paywall was opened from.
 *
 * It tailors the subhead, and nothing else. The headline is the product's
 * name on every door, and what DEEP Premium includes doesn't change with
 * where you were standing when you asked. One screen, several ways in.
 *
 * Ported from Deep/Deep/Features/Premium/Models/PaywallSource.swift; the
 * subheads themselves are string resources the paywall picks by this value.
 */
enum class PaywallSource {
  /** The "Upgrade to DEEP Premium" row in Settings. */
  Settings,

  /** A locked sound, reached from a collection, the playlist or a Home play button. */
  LockedSound,

  /** A locked plant, tapped (or confirmed) in the Garden's plant picker. */
  LockedPlant,

  /** The premium step during onboarding, after the account is made. */
  Onboarding,
}
