package io.appbeyond.freelance.deep.shared.transition

import android.os.Build
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibilityScope
import androidx.compose.animation.ContentTransform
import androidx.compose.animation.EnterExitState
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.BlurEffect
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.TileMode
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import io.appbeyond.freelance.deep.shared.components.rememberReduceMotion
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.blushPowder
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.drift
import io.appbeyond.freelance.deep.theme.hush
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.peachCloud
import io.appbeyond.freelance.deep.theme.skyWash
import io.appbeyond.freelance.deep.theme.veil

/** Which way the hand-off travels. Going back mirrors going forward. */
enum class SoftDriftDirection { Forward, Backward }

/**
 * The app's calm screen hand-off: a soft crossfade with a small vertical drift
 * ([Dp.drift]) and a breath of blur ([Dp.veil]) that resolves into focus.
 * Going forward the new content rises in from below while the old drifts
 * upward — one continuous, unhurried surfacing; going back the motion mirrors.
 * Every half runs on [hush], so every screen-level dissolve shares one tempo.
 *
 * Ported from Deep/Deep/Shared/Transition/SoftDriftTransition.swift. A SwiftUI
 * `Transition` is one value carrying opacity, offset and blur; Compose splits
 * it in two:
 *  - [enter] / [exit] / [transform] — the opacity and drift, as stock
 *    `EnterTransition` / `ExitTransition`s for `AnimatedVisibility` or an
 *    `AnimatedContent` `transitionSpec`;
 *  - [softDriftVeil] — the blur, which no stock transition draws, applied
 *    inside the animated content. A real blur exists only from API 31
 *    (`RenderEffect`), so below that the veil is skipped and the hand-off is
 *    drift and fade alone.
 *
 * Under reduced motion the drift and blur are dropped, leaving a plain
 * crossfade at the same duration — less motion, not less time. Pass
 * `fades = false` when an enclosing layer already crossfades, so opacities
 * never compound; with reduced motion that degrades to no transition at all.
 * Never veil a subtree that contains `AtmosphereBackground` — its blurred orbs
 * clip into hard-edged discs under an animated blur.
 *
 * Built by [rememberSoftDrift], which reads the density and the reduced-motion
 * setting once:
 *
 * ```
 * val drift = rememberSoftDrift()
 * AnimatedContent(route, transitionSpec = { drift.transform(direction) }) { r ->
 *   Screen(r, Modifier.softDriftVeil(this))
 * }
 * ```
 */
@Immutable
class SoftDrift internal constructor(
  private val driftPx: Int,
  /** Whether reduced motion is on — the veil reads it too. */
  val reduceMotion: Boolean,
) {

  /** The arriving half: fade in while rising from below (forward) or above (backward). */
  fun enter(
    direction: SoftDriftDirection = SoftDriftDirection.Forward,
    fades: Boolean = true,
  ): EnterTransition {
    val fade = if (fades) fadeIn(hush()) else EnterTransition.None
    if (reduceMotion) return fade
    val from = if (direction == SoftDriftDirection.Forward) driftPx else -driftPx
    return fade + slideInVertically(hush()) { from }
  }

  /** The leaving half: fade out while drifting up (forward) or down (backward). */
  fun exit(
    direction: SoftDriftDirection = SoftDriftDirection.Forward,
    fades: Boolean = true,
  ): ExitTransition {
    val fade = if (fades) fadeOut(hush()) else ExitTransition.None
    if (reduceMotion) return fade
    val to = if (direction == SoftDriftDirection.Forward) -driftPx else driftPx
    return fade + slideOutVertically(hush()) { to }
  }

  /** Both halves, for an `AnimatedContent` `transitionSpec`. */
  fun transform(
    direction: SoftDriftDirection = SoftDriftDirection.Forward,
    fades: Boolean = true,
  ): ContentTransform = enter(direction, fades) togetherWith exit(direction, fades)
}

/** The soft drift for this composition's density and reduced-motion setting. */
@Composable
fun rememberSoftDrift(): SoftDrift {
  val reduceMotion = rememberReduceMotion()
  val driftPx = with(LocalDensity.current) { Dp.drift.roundToPx() }
  return remember(driftPx, reduceMotion) { SoftDrift(driftPx, reduceMotion) }
}

/**
 * The soft drift's veil: a [Dp.veil] blur at the fully-hidden ends of [scope]'s
 * enter / exit, resolving to sharp as the content settles. Apply inside the
 * `AnimatedContent` / `AnimatedVisibility` content, on the content's root.
 *
 * A no-op below API 31 (no real blur there), under reduced motion, and when
 * [veils] is false — pass false for anything containing `AtmosphereBackground`
 * or a hosted view.
 */
@Composable
fun Modifier.softDriftVeil(scope: AnimatedVisibilityScope, veils: Boolean = true): Modifier {
  val reduceMotion = rememberReduceMotion()
  if (!veils || reduceMotion || Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return this

  val veilPx = with(LocalDensity.current) { Dp.veil.toPx() }
  val radius by scope.transition.animateFloat(
    transitionSpec = { hush() },
    label = "soft-drift-veil",
  ) { state -> if (state == EnterExitState.Visible) 0f else veilPx }

  return graphicsLayer {
    renderEffect = if (radius > 0f) BlurEffect(radius, radius, TileMode.Decal) else null
  }
}

// MARK: - Previews

@Preview(showBackground = true, name = "Soft drift")
@Composable
private fun SoftDriftPreview() {
  // Stand-ins for two screens — no real dependencies. Tap to hand off;
  // alternate taps go forward and back.
  var showsFirst by remember { mutableStateOf(true) }
  val drift = rememberSoftDrift()
  val direction = if (showsFirst) SoftDriftDirection.Backward else SoftDriftDirection.Forward

  AnimatedContent(
    targetState = showsFirst,
    transitionSpec = { drift.transform(direction) },
    label = "soft-drift-preview",
    modifier = Modifier.fillMaxSize().background(Color.moonCream),
  ) { first ->
    val stops = if (first) listOf(Color.peachCloud, Color.blushPowder) else listOf(Color.skyWash, Color.moonCream)
    Box(
      modifier = Modifier
        .softDriftVeil(this)
        .fillMaxSize()
        .background(Brush.verticalGradient(stops))
        .clickable { showsFirst = !showsFirst },
      contentAlignment = Alignment.Center,
    ) {
      Text(if (first) "First screen" else "Second screen", style = DeepType.sectionTitle, color = Color.deepPlum)
    }
  }
}
