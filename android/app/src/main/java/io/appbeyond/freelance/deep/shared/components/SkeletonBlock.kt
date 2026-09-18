package io.appbeyond.freelance.deep.shared.components

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.State
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.theme.breath
import io.appbeyond.freelance.deep.theme.chip
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.rhythm
import io.appbeyond.freelance.deep.theme.tile

/**
 * Deep's breathing skeleton primitives — never a shimmer sweep or a spinner.
 * Screen-specific skeleton layouts compose [SkeletonBlock] / [SkeletonTextLine]
 * to mirror real content geometry, then apply [Modifier.skeletonBreath] once
 * at the root.
 *
 * Ported from Deep/Deep/Shared/Components/SkeletonBlock.swift.
 */

// MARK: - Constants

/** Opacity floor of the breathing pulse. */
private const val MIN_OPACITY = 0.45f

/** Opacity ceiling of the breathing pulse. */
private const val MAX_OPACITY = 0.85f

/** Opacity held under Reduce Motion — a still midpoint, not full brightness. */
private const val REDUCED_MOTION_OPACITY = 0.65f

/** Seconds per pulse — iOS's `.breath(over: 2.6)`. */
private const val BREATH_SECONDS = 2.6f

/** Alpha of every skeleton shape's fill. */
private const val SKELETON_FILL_ALPHA = 0.55f

/** Fixed height of a skeleton text line — iOS's `height: 12`. */
private val TEXT_LINE_HEIGHT = 12.dp

// MARK: - Shapes

/**
 * A breathing skeleton block — a placeholder shape standing in for artwork or
 * a tile. Carries no intrinsic size of its own; apply `.size(...)` or
 * `.fillMaxWidth().height(...)` via [modifier], the way the real content it
 * stands in for would be sized.
 */
@Composable
fun SkeletonBlock(modifier: Modifier = Modifier, cornerRadius: Dp = Dp.tile) {
  Box(
    modifier.background(
      color = Color.White.copy(alpha = SKELETON_FILL_ALPHA),
      shape = RoundedCornerShape(cornerRadius),
    ),
  )
}

/**
 * A breathing skeleton text line — a capsule standing in for a line of copy.
 *
 * @param width a fixed width, or `null` to fill the available width.
 */
@Composable
fun SkeletonTextLine(modifier: Modifier = Modifier, width: Dp? = null) {
  Box(
    modifier
      .then(if (width != null) Modifier.width(width) else Modifier.fillMaxWidth())
      .height(TEXT_LINE_HEIGHT)
      .background(
        color = Color.White.copy(alpha = SKELETON_FILL_ALPHA),
        shape = RoundedCornerShape(Dp.chip),
      ),
  )
}

// MARK: - Breathing

/**
 * Pulses the whole subtree's opacity in unison, as one slow breath. Apply
 * once at a skeleton layout's root — never per-block, or the shapes would
 * breathe out of phase with each other.
 *
 * Honours Reduce Motion by holding at a still midpoint rather than animating,
 * and collapses the subtree's semantics into a single "Loading" node so a
 * screen reader announces the wait once instead of walking every placeholder
 * shape. **Never a shimmer sweep or a spinner** — DESIGN.md rules both out
 * explicitly.
 */
@Composable
fun Modifier.skeletonBreath(): Modifier {
  val reduceMotion = rememberReduceMotion()

  val opacity: State<Float> = if (reduceMotion) {
    remember { mutableStateOf(REDUCED_MOTION_OPACITY) }
  } else {
    val transition = rememberInfiniteTransition(label = "skeleton-breath")
    transition.animateFloat(
      initialValue = MIN_OPACITY,
      targetValue = MAX_OPACITY,
      animationSpec = infiniteRepeatable(
        animation = breath(BREATH_SECONDS),
        repeatMode = RepeatMode.Reverse,
      ),
      label = "skeleton-breath-opacity",
    )
  }
  val opacityValue by opacity

  return this
    .graphicsLayer { alpha = opacityValue }
    .clearAndSetSemantics { contentDescription = "Loading" }
}

// MARK: - Preview

@Preview(showBackground = true, name = "Skeleton block")
@Composable
private fun SkeletonBlockPreview() {
  Box(Modifier.fillMaxSize().background(Color.moonCream)) {
    Column(
      modifier = Modifier.padding(Dp.rhythm).skeletonBreath(),
      verticalArrangement = Arrangement.spacedBy(Dp.rhythm),
    ) {
      SkeletonBlock(modifier = Modifier.size(150.dp))
      SkeletonTextLine(width = 120.dp)
      SkeletonTextLine()
    }
  }
}
