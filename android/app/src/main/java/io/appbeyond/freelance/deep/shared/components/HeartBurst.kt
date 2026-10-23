package io.appbeyond.freelance.deep.shared.components

import androidx.compose.animation.core.Animatable
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.shape.GenericShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.blushPowder
import io.appbeyond.freelance.deep.theme.chip
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.exhale
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.softLilac
import kotlinx.coroutines.launch

// MARK: - Constants

/** The heart — iOS's 18pt bold `heart.fill`, measured to its glyph box. */
private val HEART_SIZE = DpSize(20.dp, 19.dp)

/** Where the heart starts, just clear of the anchor, and where it drifts to. */
private val RISE_FROM = (-6).dp
private val RISE_TO = (-50).dp

/** The bloom: small at first so it is visible from its first frame, then a touch past full. */
private const val SCALE_FROM = 0.6f
private const val SCALE_TO = 1.05f

/** The heart's glow — iOS's `shadow(lavenderMist 0.4, radius: 8, y: 2)`. */
private const val GLOW_ALPHA = 0.4f
private val GLOW_RADIUS = 8.dp
private val GLOW_OFFSET_Y = 2.dp

/**
 * A filled heart drawn to its box: the outline of `DeepIcons.Heart`, its
 * 3.75…20.25 × 3.75…20 extent stretched to fill the shape's bounds, so the
 * glow hugs the heart rather than a padded square.
 */
private val HeartShape = GenericShape { size, _ ->
  val minX = 3.75f
  val minY = 3.75f
  val sx = size.width / (20.25f - minX)
  val sy = size.height / (20f - minY)
  fun x(v: Float) = (v - minX) * sx
  fun y(v: Float) = (v - minY) * sy
  moveTo(x(12f), y(20f))
  cubicTo(x(12f), y(20f), x(3.75f), y(14.5f), x(3.75f), y(9f))
  cubicTo(x(3.75f), y(6.1f), x(6.1f), y(3.75f), x(9f), y(3.75f))
  cubicTo(x(10.7f), y(3.75f), x(12f), y(4.7f), x(12f), y(6.3f))
  cubicTo(x(12f), y(4.7f), x(13.3f), y(3.75f), x(15f), y(3.75f))
  cubicTo(x(17.9f), y(3.75f), x(20.25f), y(6.1f), x(20.25f), y(9f))
  cubicTo(x(20.25f), y(14.5f), x(12f), y(20f), x(12f), y(20f))
  close()
}

// MARK: - Burst

/**
 * A small flourish for the one-tap heart: each time [trigger] changes, a heart
 * blooms out of the top of [content] and drifts away — rising from −6 to −50dp,
 * scaling 0.6 → 1.05 and fading out over the exhale — so sending feels alive,
 * paired with a light haptic, since giving is the feature's one moment worth
 * feeling.
 *
 * Ported from Deep/Deep/Features/CompassionPortfolio/Components/HeartBurst.swift
 * (iOS's `.heartBurst(trigger:)` modifier; a wrapper here, since a Compose
 * modifier cannot host an overlay). The heart never takes touches and never
 * changes [content]'s size. Reduced motion skips the float; the haptic still
 * fires. A [trigger] of 0 (or less) only buzzes, as iOS's guard does.
 */
@Composable
fun HeartBurst(
  trigger: Int,
  modifier: Modifier = Modifier,
  content: @Composable () -> Unit,
) {
  val haptics = LocalHapticFeedback.current
  val reduceMotion = rememberReduceMotion()
  val rise = remember { Animatable(RISE_FROM.value) }
  val scale = remember { Animatable(SCALE_FROM) }
  val opacity = remember { Animatable(0f) }
  // The value already burst for: a change, not the first composition, fires it.
  var seen by remember { mutableIntStateOf(trigger) }

  LaunchedEffect(trigger) {
    if (trigger == seen) return@LaunchedEffect
    seen = trigger
    haptics.performHapticFeedback(HapticFeedbackType.ContextClick)
    if (trigger <= 0) return@LaunchedEffect
    if (reduceMotion) {
      opacity.snapTo(0f)
      return@LaunchedEffect
    }
    rise.snapTo(RISE_FROM.value)
    scale.snapTo(SCALE_FROM)
    opacity.snapTo(1f)
    launch { rise.animateTo(RISE_TO.value, exhale()) }
    launch { scale.animateTo(SCALE_TO, exhale()) }
    launch { opacity.animateTo(0f, exhale()) }
  }

  Box(modifier) {
    content()
    // matchParentSize so the heart never sizes the anchor; requiredSize so it
    // keeps its own size over an anchor smaller than it.
    Box(Modifier.matchParentSize(), contentAlignment = Alignment.TopCenter) {
      Box(
        Modifier
          .requiredSize(HEART_SIZE)
          .graphicsLayer {
            translationY = rise.value.dp.toPx()
            scaleX = scale.value
            scaleY = scale.value
            alpha = opacity.value
            // Not an offscreen layer: one would clip the glow to the heart's box.
            compositingStrategy = CompositingStrategy.ModulateAlpha
          }
          .dropShadow(
            shape = HeartShape,
            shadow = Shadow(
              radius = GLOW_RADIUS,
              color = Color.lavenderMist.copy(alpha = GLOW_ALPHA),
              offset = DpOffset(0.dp, GLOW_OFFSET_Y),
            ),
          )
          .background(Color.blushPowder, HeartShape),
      )
    }
  }
}

// MARK: - Previews

@Preview(showBackground = true, name = "Heart burst")
@Composable
private fun HeartBurstPreview() {
  var count by remember { mutableIntStateOf(0) }
  Box(Modifier.fillMaxSize().background(Color.moonCream), contentAlignment = Alignment.Center) {
    HeartBurst(trigger = count) {
      Box(
        Modifier
          .background(Color.softLilac, RoundedCornerShape(Dp.chip))
          .clickable { count += 1 }
          .padding(horizontal = 28.dp, vertical = 12.dp),
      ) {
        Text("Send", style = DeepType.bodyMedium, color = Color.deepPlum)
      }
    }
  }
}
