package io.appbeyond.freelance.deep.shared.components

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import io.appbeyond.freelance.deep.theme.blushPowder
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.peachCloud
import io.appbeyond.freelance.deep.theme.skyWash
import io.appbeyond.freelance.deep.theme.softLilac

/**
 * The gradient pairings artwork falls back to, exactly as iOS names and mixes
 * them — the causes, projects and reports of the Compassion portfolio wear
 * these.
 *
 * Ported from Deep/Deep/Features/DeepSound/Models/ArtworkPalette.swift. Every
 * stop is a palette token or a token deepened toward [deepPlum], so no raw
 * colour enters here. [ArtworkImage]'s server palette names resolve through
 * their own (older, Android-tuned) map; this enum is the iOS one, for content
 * that is authored in the app rather than sent by the server.
 */
enum class ArtworkPalette(val colors: List<Color>) {
  Tide(listOf(Color.skyWash, Color.softLilac)),
  Dusk(listOf(Color.lavenderMist, Color.blushPowder)),
  Bloom(listOf(Color.blushPowder, Color.softLilac)),
  Ember(listOf(Color.peachCloud, Color.blushPowder)),
  Mist(listOf(Color.softLilac, Color.skyWash)),
  Aurora(listOf(Color.skyWash, Color.lavenderMist, Color.blushPowder)),
  Dawn(listOf(Color.moonCream, Color.peachCloud)),

  // Single-hue pairings: one colour falling into a deeper shade of itself.
  Veil(deepening(Color.softLilac, to = 0.08f)),
  Petal(deepening(Color.blushPowder, to = 0.12f)),
  Iris(deepening(Color.lavenderMist, from = 0.22f, to = 0.34f)),
  Shore(deepening(Color.skyWash, to = 0.12f)),
  Hearth(deepening(Color.peachCloud, to = 0.12f));
}

/** iOS's `colour.mix(with: .deepPlum, by:)`, at two depths. */
private fun deepening(colour: Color, from: Float = 0f, to: Float): List<Color> =
  listOf(lerp(colour, Color.deepPlum, from), lerp(colour, Color.deepPlum, to))
