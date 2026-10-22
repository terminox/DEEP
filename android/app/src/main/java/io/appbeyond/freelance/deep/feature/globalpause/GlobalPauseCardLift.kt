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
 * THE CARD LIFT — iOS `Transitions/GlobalPauseCardLiftTransition.swift`.
 *
 * Tapping the live card in Fuku's Lounge doesn't cut to the session: the
 * card's chrome fades, then the card itself grows until its night sky and
 * globe ARE the session's backdrop, and the meditation overlay cascades in
 * once it lands. Leaving mid-sit flies it home; leaving from the ending's
 * cream simply fades.
 *
 * The seam has four ends, each applied where its screen already composes:
 * - [cardLiftSource] on the lounge's `GlobalPauseCard` — where the lift starts.
 * - [cardLiftTarget] on the session's backdrop (night sky + globe), inside the
 *   presentation's `AnimatedVisibility` in `AppRoot`, whose scope it is handed.
 * - [cardLiftCover] on the ending's opaque layer — while it covers the
 *   backdrop, there is nothing left to fly.
 * - [enter] / [exit] for that presentation, and [landingMillis] for when the
 *   overlay may cascade in.
 *
 * Both the card and the session draw ONE shared `GlobeScene` through
 * `LocalGlobeRendering`, so the lift moves one world rather than swapping
 * two. Implementations: `EarthCardLift` (the lift, or a plain crossfade under
 * reduced motion) and [CrossfadeCardLift] (previews, and the default).
 */
@Stable
interface GlobalPauseCardLift {

  /** Marks the card that lifts. Call inside `with(lift) { … }`. */
  fun Modifier.cardLiftSource(): Modifier

  /** Marks where it lands, in the presentation's [visibility] scope. */
  @Composable
  fun Modifier.cardLiftTarget(visibility: AnimatedVisibilityScope): Modifier

  /** Marks a layer that hides the backdrop for as long as it is composed. */
  @Composable
  fun Modifier.cardLiftCover(): Modifier

  val enter: EnterTransition

  val exit: ExitTransition

  /** How long after the presentation begins the overlay may reveal, in ms. */
  val landingMillis: Long
}

/** No lift — a crossfade, and the overlay reveals as it lands. */
object CrossfadeCardLift : GlobalPauseCardLift {
  override fun Modifier.cardLiftSource(): Modifier = this

  @Composable
  override fun Modifier.cardLiftTarget(visibility: AnimatedVisibilityScope): Modifier = this

  @Composable
  override fun Modifier.cardLiftCover(): Modifier = this

  override val enter: EnterTransition = fadeIn(hush())
  override val exit: ExitTransition = fadeOut(hush())
  override val landingMillis: Long = hush<Float>().durationMillis.toLong()
}

/** The lift every Global Pause screen reads. */
val LocalGlobalPauseCardLift = staticCompositionLocalOf<GlobalPauseCardLift> { CrossfadeCardLift }

/** Read the lift from a composable without importing the local. */
val currentCardLift: GlobalPauseCardLift
  @Composable get() = LocalGlobalPauseCardLift.current
