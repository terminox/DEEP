package io.appbeyond.freelance.deep.theme

import androidx.compose.ui.graphics.Color

// MARK: - Palette (single source of truth)

/**
 * Foliage and light for the Mind Garden. The core DEEP palette (DeepColor.kt) is intentionally floral pastel and carries neither green nor
 * gold, so the garden introduces a small, restrained set of its own — muted
 * sages for the plant, one honey for the sunlight that feeds it — that
 * harmonise with the surrounding lavender / blush atmosphere rather than
 * fighting it.
 *
 * Ported from Deep/Deep/Features/MindGarden/GardenPalette.swift (`GardenColor`).
 * Every garden colour originates here; the [Color] accessors below are thin
 * projections — never duplicate a hex literal elsewhere.
 */
private object GardenPalette {
  val Meadow = Color(0xFFCFE1C6)
  val Sage = Color(0xFFA5C69E)
  val Fern = Color(0xFF739D78)

  /**
   * Sunlight — the garden's currency, dimmed to the same tonal weight as
   * [Fern] so the figure it marks reads with equal strength on frost.
   */
  val Sunbeam = Color(0xFFB5954A)
}

// MARK: - Colours

/*
 * Extensions on Color.Companion, like the core palette, so a call site reads
 * `Color.fern` the way SwiftUI reads `GardenColor.fern`.
 */

val Color.Companion.meadow: Color get() = GardenPalette.Meadow
val Color.Companion.sage: Color get() = GardenPalette.Sage
val Color.Companion.fern: Color get() = GardenPalette.Fern
val Color.Companion.sunbeam: Color get() = GardenPalette.Sunbeam
