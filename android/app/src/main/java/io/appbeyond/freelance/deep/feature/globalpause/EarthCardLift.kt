package io.appbeyond.freelance.deep.feature.globalpause

import androidx.compose.animation.AnimatedVisibilityScope
import androidx.compose.animation.EnterExitState
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.remember
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.geometry.lerp
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import io.appbeyond.freelance.deep.feature.globalpause.globe.GlobeFlight
import io.appbeyond.freelance.deep.feature.globalpause.globe.unclippedRectInRoot
import io.appbeyond.freelance.deep.theme.card
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.exhaleEasing
import io.appbeyond.freelance.deep.theme.hush
import io.appbeyond.freelance.deep.theme.land
import io.appbeyond.freelance.deep.theme.lift

/**
 * The card lift, ported from iOS `GlobalPauseCardLiftTransition` +
 * `GlobalPauseCardView`'s globe flight — as geometry, not a crossfade.
 *
 * iOS re-parents one card view into the presented controller and animates its
 * frame. Compose can't move a live `TextureView` between parents, so the
 * session's backdrop plays the card instead:
 *
 * 1. **Pre-fade.** The backdrop — night sky and globe, no chrome — appears
 *    exactly over the card (clipped to its rect and corner radius, its sky
 *    anchored at the card's corner) and fades in over it, which reads as the
 *    card's chrome and scrim fading away (iOS's 0.22s pre-fade, then its
 *    0.25s beat). The session's globe surface draws its first frames under
 *    that fade; until it has one, the backdrop stays invisible, so the
 *    hand-off from the card's surface to the session's never blinks.
 * 2. **Flight.** The clip grows from the card's rect to the screen, the
 *    corners straighten, the feed beneath dims, and the session's globe —
 *    laid out once, at its resting size — rides a transform from the card's
 *    corner seat to the centre (`GlobeFlight`, read by the Earth renderer),
 *    so its surface is never resized mid-flight.
 * 3. **Home.** Leaving mid-meditation plays it backwards and fades the
 *    backdrop off the card as it settles, uncovering the card's own chrome.
 *    Leaving from the ending's cream ([cardLiftCover]) is a plain fade, as
 *    iOS's `FadeOutAnimator` is once the card has gone home.
 *
 * Under reduced motion (animator duration scale 0) there is no flight: a
 * crossfade, as iOS's reduce-motion users get a fade.
 */
@Stable
class EarthCardLift(
  private val flight: GlobeFlight,
  private val reduceMotion: Boolean,
) : GlobalPauseCardLift {

  override fun Modifier.cardLiftSource(): Modifier =
    onGloballyPositioned { flight.cardBounds = it.unclippedRectInRoot() }

  @Composable
  override fun Modifier.cardLiftTarget(visibility: AnimatedVisibilityScope): Modifier {
    val transition = visibility.transition
    LaunchedEffect(transition) {
      snapshotFlow { transition.currentState to transition.targetState }.collect { (current, target) ->
        flight.phase = when {
          target == EnterExitState.PostExit -> GlobeFlight.Phase.Returning
          current == EnterExitState.Visible && target == EnterExitState.Visible -> GlobeFlight.Phase.Landed
          else -> GlobeFlight.Phase.Lifting
        }
      }
    }
    DisposableEffect(Unit) { onDispose { flight.reset() } }
    val tracked = onGloballyPositioned { flight.backdropBounds = it.unclippedRectInRoot() }
    if (reduceMotion) return tracked

    // Decided once, as the presentation begins: no card on screen to lift
    // from means a plain fade in place.
    val lifts = remember { flight.cardBounds != null }
    val atRest = { state: EnterExitState ->
      state == EnterExitState.Visible || (state == EnterExitState.PostExit && flight.covered)
    }
    val progress = transition.animateFloat(
      transitionSpec = { if (targetState == EnterExitState.Visible) lift(delayMillis = PRE_BEAT_MILLIS) else land() },
      label = "card-lift",
    ) { state -> if (!lifts || atRest(state)) 1f else 0f }
    val veil = transition.animateFloat(
      transitionSpec = {
        when {
          !lifts -> hush()
          targetState == EnterExitState.Visible -> tween(PRE_FADE_MILLIS, easing = exhaleEasing)
          else -> tween(RETURN_FADE_MILLIS, delayMillis = RETURN_FADE_DELAY_MILLIS, easing = exhaleEasing)
        }
      },
      label = "card-lift-veil",
    ) { state -> if (atRest(state)) 1f else 0f }
    val ready = animateFloatAsState(
      targetValue = if (flight.sessionReady) 1f else 0f,
      animationSpec = tween(READY_FADE_MILLIS, easing = exhaleEasing),
      label = "card-lift-ready",
    )
    SideEffect { flight.progressSource = progress }

    val cornerRadius = with(LocalDensity.current) { Dp.card.toPx() }
    val dim = Color.deepPlum
    return tracked
      // The feed recedes under the lift (iOS's presentation-controller dim).
      .drawBehind { drawRect(dim, alpha = DIM_ALPHA * minOf(progress.value, veil.value).coerceIn(0f, 1f)) }
      .graphicsLayer {
        val p = progress.value
        // Never quite zero while the session's surface is getting its first
        // frame: a layer at alpha 0 may be skipped, and a TextureView that is
        // never drawn never gets a surface to show that frame on.
        alpha = veil.value.coerceIn(0f, 1f) * maxOf(ready.value, PREPARING_ALPHA)
        val card = flight.cardBounds
        val origin = flight.backdropBounds
        if (lifts && card != null && origin != null && p < 1f) {
          val local = card.translate(-origin.left, -origin.top)
          clip = true
          shape = FlightShape(lerp(local, Rect(0f, 0f, size.width, size.height), p), cornerRadius * (1f - p))
        } else {
          clip = false
          shape = RectangleShape
        }
      }
  }

  @Composable
  override fun Modifier.cardLiftCover(): Modifier {
    DisposableEffect(Unit) {
      flight.covered = true
      onDispose { flight.covered = false }
    }
    return this
  }

  override val enter: EnterTransition = if (reduceMotion) fadeIn(hush()) else EnterTransition.None

  /** Read as the presentation leaves: a flight home holds the content itself
   * (its animations ride the presentation's transition); a covered backdrop,
   * or reduced motion, fades. */
  override val exit: ExitTransition
    get() = if (reduceMotion || flight.covered) fadeOut(hush()) else ExitTransition.None

  override val landingMillis: Long =
    if (reduceMotion) hush<Float>().durationMillis.toLong() else (PRE_BEAT_MILLIS + lift<Float>().durationMillis).toLong()

  /** The backdrop's visible rect mid-flight, rounded. */
  private data class FlightShape(val rect: Rect, val radius: Float) : Shape {
    override fun createOutline(size: Size, layoutDirection: LayoutDirection, density: Density): Outline =
      Outline.Rounded(RoundRect(rect, CornerRadius(radius)))
  }

  private companion object {
    /** iOS's chrome pre-fade (0.22s) — here, the backdrop fading in over the card. */
    const val PRE_FADE_MILLIS = 220

    /** The pre-fade plus iOS's 0.25s beat before the flight. */
    const val PRE_BEAT_MILLIS = 470

    /** Flying home, the card's chrome returns late, as the card settles. */
    const val RETURN_FADE_DELAY_MILLIS = 260
    const val RETURN_FADE_MILLIS = 200

    const val READY_FADE_MILLIS = 120
    const val PREPARING_ALPHA = 0.004f

    /** iOS's plum dim under the presentation. */
    const val DIM_ALPHA = 0.18f
  }
}
