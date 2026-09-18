package io.appbeyond.freelance.deep.shared.components

import androidx.compose.animation.core.Animatable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.nestedscroll.NestedScrollConnection
import androidx.compose.ui.input.nestedscroll.NestedScrollSource
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.Velocity
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.theme.settle
import kotlinx.coroutines.launch
import kotlin.math.exp
import kotlin.math.min

/**
 * A sticky, stretchy hero header.
 *
 * The media draws full-bleed under the status bar. Pulling down grows the scene
 * from the top edge while it stays pinned; its bottom feathers to transparent so
 * it dissolves into the atmosphere rather than ending on a hard line. Scrolling
 * up drifts it away more slowly than the content, so it sinks behind the page
 * with depth.
 *
 * Ported from Deep/Deep/Shared/Components/StretchyHero.swift, damping constants
 * intact. Two things differ, both forced by the platform:
 *
 * 1. **SwiftUI hands you the overscroll; Compose does not.** `geo.frame(in:
 *    .scrollView).minY` goes positive on a rubber-band pull. A `LazyColumn`
 *    reports nothing below zero — the platform gives you a stretch *effect*
 *    rather than a scroll *value* — so the pull has to be gathered by a
 *    [NestedScrollConnection] and released by hand. Use [rememberHeroPull].
 * 2. The stock overscroll glow must be suppressed where this is used, or two
 *    stretch effects fight each other.
 */
@Composable
fun StretchyHero(
  pull: HeroPull,
  listState: LazyListState,
  modifier: Modifier = Modifier,
  height: Dp = 320.dp,
  content: @Composable () -> Unit,
) {
  val density = LocalDensity.current

  // How far the page has travelled upward. Only the first item matters: once it
  // is off-screen the hero has long since dissolved.
  val scrolledUp by remember(listState) {
    derivedStateOf {
      if (listState.firstVisibleItemIndex > 0) Float.MAX_VALUE
      else listState.firstVisibleItemScrollOffset.toFloat()
    }
  }

  Box(
    modifier
      .fillMaxWidth()
      .height(height)
  ) {
    Box(
      Modifier
        .fillMaxWidth()
        .graphicsLayer {
          val pullPx = pull.value
          val stretch = damp(pullPx, with(density) { FREE_STRETCH.toPx() }, with(density) { MAX_STRETCH.toPx() })
          val heightPx = with(density) { height.toPx() }

          // Grow from the top edge.
          scaleY = (heightPx + stretch) / heightPx
          transformOrigin = androidx.compose.ui.graphics.TransformOrigin(0.5f, 0f)

          // Cancel the frame's own ride down 1:1 with the RAW pull, not the
          // damped stretch. Offsetting by the stretch instead leaves a gap that
          // slides the hero down off the top edge on a deep drag.
          translationY = -pullPx + scrolledUp * PARALLAX_DEPTH

          alpha = 1f - min(1f, scrolledUp / with(density) { FADE_DISTANCE.toPx() })
          clip = true
        }
        .fillMaxSize()
        // The feathered bottom, as a destination-in mask so the media itself
        // fades rather than being covered by a matching rectangle — which would
        // only work over a flat colour, and the atmosphere is not flat.
        .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }
        .drawWithContent {
          drawContent()
          drawRect(
            brush = Brush.verticalGradient(
              colorStops = arrayOf(
                0f to Color.Black,
                0.78f to Color.Black,
                1f to Color.Transparent,
              ),
            ),
            blendMode = BlendMode.DstIn,
          )
        },
    ) {
      content()
    }
  }
}

/** The overscroll the hero has absorbed, in pixels. Never negative. */
@JvmInline
value class HeroPull(val value: Float)

/**
 * Gathers downward overscroll at the top of [listState] into a [HeroPull], and
 * lets it go when the finger does.
 *
 * Returns the pull and the connection to hand to `Modifier.nestedScroll`.
 */
@Composable
fun rememberHeroPull(listState: LazyListState): Pair<HeroPull, NestedScrollConnection> {
  val scope = rememberCoroutineScope()
  val pull = remember { Animatable(0f) }

  val connection = remember(listState) {
    object : NestedScrollConnection {
      override fun onPreScroll(available: Offset, source: NestedScrollSource): Offset {
        val atTop = listState.firstVisibleItemIndex == 0 &&
          listState.firstVisibleItemScrollOffset == 0

        // Give the accumulated pull back before the list scrolls again, so
        // reversing a drag unwinds the stretch rather than scrolling the page
        // while the hero stays stretched.
        if (available.y < 0 && pull.value > 0f) {
          val taken = min(-available.y, pull.value)
          scope.launch { pull.snapTo(pull.value - taken) }
          return Offset(0f, -taken)
        }

        if (available.y > 0 && atTop && source == NestedScrollSource.UserInput) {
          scope.launch { pull.snapTo(pull.value + available.y) }
          return available
        }

        return Offset.Zero
      }

      override suspend fun onPreFling(available: Velocity): Velocity {
        if (pull.value > 0f) {
          pull.animateTo(0f, settle())
          return available
        }
        return Velocity.Zero
      }
    }
  }

  return HeroPull(pull.value) to connection
}

/**
 * Overscroll absorbed 1:1 up to [free], then easing asymptotically toward [max],
 * so a casual bounce looks like an uncapped hero and a deep pull cannot balloon
 * the scene.
 */
private fun damp(pull: Float, free: Float, max: Float): Float =
  if (pull <= free) pull
  else free + (max - free) * (1f - exp(-(pull - free) / (max - free)))

/** Overscroll the hero absorbs before the stretch starts damping. */
private val FREE_STRETCH = 48.dp

/** Asymptotic ceiling on the stretch. */
private val MAX_STRETCH = 96.dp

/**
 * Distance scrolled up over which the hero fully dissolves. Shorter than the
 * hero's height, so it has melted away before it would otherwise leave.
 */
private val FADE_DISTANCE = 220.dp

/** How much slower the hero drifts than the scroll. ~0.4 reads as gentle depth. */
private const val PARALLAX_DEPTH = 0.4f
