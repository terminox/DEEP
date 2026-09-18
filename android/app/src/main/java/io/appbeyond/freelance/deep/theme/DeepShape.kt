package io.appbeyond.freelance.deep.theme

import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

// MARK: - Corner radii

/*
 * Extensions on Dp.Companion so a call site reads `RoundedCornerShape(Dp.card)`
 * and `Modifier.padding(horizontal = Dp.edge)`, the way the SwiftUI side reads
 * `RoundedRectangle(cornerRadius: .card)` and `.padding(.horizontal, .edge)`.
 *
 * Ported from Deep/Deep/Theme/DeepTheme.swift. iOS points and Android dp are the
 * same unit of intent — a 24pt card is a 24dp card.
 */

/** Primary cards and hero artwork. */
val Dp.Companion.card: Dp get() = 24.dp

/** Fully rounded chips and pills. */
val Dp.Companion.chip: Dp get() = 999.dp

/** Tiles and small artwork. */
val Dp.Companion.tile: Dp get() = 20.dp

// MARK: - Spacing

/** Screen horizontal inset. Nothing crowds an edge. */
val Dp.Companion.edge: Dp get() = 20.dp

/** Vertical rhythm between sections. */
val Dp.Companion.rhythm: Dp get() = 24.dp
