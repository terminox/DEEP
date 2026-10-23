package io.appbeyond.freelance.deep.theme

import androidx.compose.ui.graphics.Color

// MARK: - Palette (single source of truth)

/**
 * The DEEP palette. Every colour the app uses originates here; the [Color]
 * accessors below are thin projections of these values — never duplicate a hex
 * literal elsewhere.
 *
 * Ported from Deep/Deep/Theme/DeepTheme.swift. The four values that also exist in
 * res/values/colors.xml are duplicated there only because the platform needs them
 * before Compose runs (window background, splash, launcher icon); keep the two in
 * step.
 */
private object DeepPalette {
  val LavenderMist = Color(0xFFB8A7E8)
  val SoftLilac = Color(0xFFD4C5F0)
  val BlushPowder = Color(0xFFF4C9D4)
  val SkyWash = Color(0xFFC5D8F0)
  val PeachCloud = Color(0xFFF5D9C4)
  val MoonCream = Color(0xFFFBF7FF)
  val DeepPlum = Color(0xFF3D3654)
  val DriftGrey = Color(0xFF8B82A8)

  /**
   * Destructive accent — a rose dimmed to dusk, red enough to warn without
   * breaking the pastel register. For irreversible actions (delete account).
   */
  val DuskRose = Color(0xFFC25E6E)

  /**
   * The logo's violet brought into the pastel register — the wordmark's ink
   * indigo lifted out of the dark and dimmed to dusk. Sits below the palette's
   * lightness floor on purpose: it has to hold the wordmark against sunrise
   * footage, where [LavenderMist] washes out.
   */
  val IrisDusk = Color(0xFF9A8CCE)

  /**
   * Global Pause's night: the top of the sky the globe hangs in, its horizon,
   * and the veil that deepens it under the card's text. Night-only shades,
   * darker than any daytime token — iOS's `NightSkyBackground` mixes its sky
   * from dusk to night at 0.90 (zenith) and 0.60 (horizon), and the card
   * chrome's scrim is its own raw night-plum.
   */
  val NightZenith = Color(0xFF0F0C20)
  val NightHorizon = Color(0xFF1F1934)
  val NightVeil = Color(0xFF0D0A1C)
}

// MARK: - Colours

/*
 * Extending Color.Companion rather than collecting the tokens into an object is
 * what makes them read as built-ins at the call site — `Color.lavenderMist`,
 * `Color.deepPlum.copy(alpha = 0.4f)` — exactly as the SwiftUI side reads
 * `.foregroundStyle(.lavenderMist)`. A `DeepColors.primary` bag is the thing the
 * project's token rules exist to prevent.
 */

val Color.Companion.lavenderMist: Color get() = DeepPalette.LavenderMist
val Color.Companion.softLilac: Color get() = DeepPalette.SoftLilac
val Color.Companion.blushPowder: Color get() = DeepPalette.BlushPowder
val Color.Companion.skyWash: Color get() = DeepPalette.SkyWash
val Color.Companion.peachCloud: Color get() = DeepPalette.PeachCloud
val Color.Companion.moonCream: Color get() = DeepPalette.MoonCream
val Color.Companion.deepPlum: Color get() = DeepPalette.DeepPlum
val Color.Companion.driftGrey: Color get() = DeepPalette.DriftGrey
val Color.Companion.duskRose: Color get() = DeepPalette.DuskRose
val Color.Companion.irisDusk: Color get() = DeepPalette.IrisDusk
val Color.Companion.nightZenith: Color get() = DeepPalette.NightZenith
val Color.Companion.nightHorizon: Color get() = DeepPalette.NightHorizon
val Color.Companion.nightVeil: Color get() = DeepPalette.NightVeil
