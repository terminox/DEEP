package io.appbeyond.freelance.deep.feature.onboarding.components

import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.layout
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * How far a scrolling list of frosted cards reaches past its column on each
 * side, so the cards' blooms breathe past the viewport instead of being sliced
 * off at its edge. The list then pads its content back in by the same amount,
 * so the cards themselves still line up with the column.
 */
internal val BLOOM_ROOM: Dp = 24.dp

/**
 * Lets a scroll container draw [horizontal] past both sides of its slot while
 * reporting the slot's own width to its parent — the Compose stand-in for
 * iOS's `.scrollClipDisabled()`, which a lazy list has no equivalent of (it
 * always clips to its bounds). Pair with a matching horizontal content padding.
 */
internal fun Modifier.bloomBleed(horizontal: Dp = BLOOM_ROOM): Modifier = layout { measurable, constraints ->
  val extra = horizontal.roundToPx() * 2
  val widened = constraints.copy(
    minWidth = constraints.minWidth + extra,
    maxWidth = if (constraints.hasBoundedWidth) constraints.maxWidth + extra else constraints.maxWidth,
  )
  val placeable = measurable.measure(widened)
  layout((placeable.width - extra).coerceAtLeast(0), placeable.height) {
    placeable.place(-extra / 2, 0)
  }
}
