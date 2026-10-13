package io.appbeyond.freelance.deep.feature.globalpause

import androidx.compose.animation.AnimatedVisibilityScope
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import io.appbeyond.freelance.deep.theme.hush

/**
 * THE CARD-LIFT HOOK, left for week 7.
 *
 * On iOS (`Transitions/GlobalPauseCardLiftTransition.swift`) tapping the live
 * card in Fuku's Lounge doesn't cut to the session: the card itself lifts and
 * grows until its night sky and globe *are* the session's backdrop, with the
 * chrome faded out before the flight and the meditation overlay cascading in
 * after it lands. The reverse plays on leaving.
 *
 * Week 6 presents the session with a plain [hush] crossfade, but routes
 * everything the lift will need through this one seam, so week 7 replaces the
 * implementation here and nowhere else:
 *
 * - [cardLiftSource] wraps the lounge card's surface (`GlobalPauseCard`).
 *   Week 7 makes it a `sharedBounds` source keyed [KEY], inside the shell's
 *   `AnimatedContent` scope that the lounge already composes in.
 * - [cardLiftTarget] wraps the session's backdrop (night sky + globe) inside
 *   the presentation's `AnimatedVisibility` in `AppRoot`, whose scope it is
 *   handed.
 * - [enter] / [exit] are that presentation's transitions — a crossfade now,
 *   the lift's choreography then.
 * - [onLanded] is when the meditation overlay may cascade in: at once now,
 *   after the flight settles then (iOS's `viewDidAppear` reveal).
 *
 * Both card and session already draw one shared `GlobeScene` through
 * `LocalGlobeRendering`, so the lift moves one globe rather than swapping two.
 * A `SharedTransitionLayout` will be needed above both — `AppRoot`'s root
 * `Box` is the common ancestor of the shell and the presentation.
 */
@Stable
interface GlobalPauseCardLift {

  /** Marks the card that lifts. Call inside `with(lift) { … }`. */
  fun Modifier.cardLiftSource(): Modifier

  /** Marks where it lands, in the presentation's [visibility] scope. */
  fun Modifier.cardLiftTarget(visibility: AnimatedVisibilityScope): Modifier

  val enter: EnterTransition

  val exit: ExitTransition

  /** How long after the presentation begins the overlay may reveal, in ms. */
  val landingMillis: Long

  companion object {
    /** The shared-element key both ends of the lift will use. */
    const val KEY = "global-pause-card"
  }
}

/** Week 6: no lift — a crossfade, and the overlay reveals as it lands. */
object CrossfadeCardLift : GlobalPauseCardLift {
  override fun Modifier.cardLiftSource(): Modifier = this
  override fun Modifier.cardLiftTarget(visibility: AnimatedVisibilityScope): Modifier = this
  override val enter: EnterTransition = fadeIn(hush())
  override val exit: ExitTransition = fadeOut(hush())
  override val landingMillis: Long = hush<Float>().durationMillis.toLong()
}

/** The lift every Global Pause screen reads. */
val LocalGlobalPauseCardLift = staticCompositionLocalOf<GlobalPauseCardLift> { CrossfadeCardLift }

/** Read the lift from a composable without importing the local. */
val currentCardLift: GlobalPauseCardLift
  @Composable get() = LocalGlobalPauseCardLift.current
