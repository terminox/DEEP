package io.appbeyond.freelance.deep.theme

import androidx.compose.ui.graphics.Color

// MARK: - Palette (single source of truth)

/**
 * The Deep palette. Every colour the app uses originates here; the [Color]
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
