package io.appbeyond.freelance.deep.theme

import androidx.compose.foundation.background
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp

/** The panel's white wash — iOS's `.white.opacity(0.38)`. */
private const val PEBBLE_ALPHA = 0.38f

/**
 * The inset tonal panel that groups content inside a frosted card. Wherever a
 * rule would normally divide, this defines the group instead — the separator
 * this project doesn't draw.
 *
 * Ported from the `pebble(cornerRadius:)` extension in
 * Deep/Deep/Features/CompassionPortfolio/Components/ImpactPebbles.swift.
 */
fun Modifier.pebble(cornerRadius: Dp = Dp.tile): Modifier =
  background(Color.White.copy(alpha = PEBBLE_ALPHA), RoundedCornerShape(cornerRadius))
