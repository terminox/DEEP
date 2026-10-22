package io.appbeyond.freelance.deep.feature.globalpause.globe

import androidx.compose.runtime.Stable
import androidx.compose.runtime.State
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.lerp
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.unit.toSize
import kotlin.math.abs

/**
 * Where the globe is in the card lift — the state the lift
 * (`EarthCardLift`) and the renderer (`EarthGlobeRendering`) share, so the
 * session's globe can ride the flight the way iOS's `GlobalPauseCardView`
 * pins its globe and animates only its transform (`beginGlobeFlight`).
 *
 * All rects are in ROOT coordinates and UNCLIPPED (position + size, not
 * `boundsInRoot`, which the card's rounded clip and the list viewport would
 * cut short). The geometry rects are plain fields: they are written on every
 * layout pass of a scrolling card and only read while a flight draws, so
 * making them observable would only invalidate for nothing.
 */
@Stable
class GlobeFlight {

  enum class Phase {
    /** No session presented: the card is the globe. */
    Resting,

    /** The card rising into the session (pre-fade, then flight). */
    Lifting,

    /** At rest in the session: the card's globe sleeps beneath it. */
    Landed,

    /** Flying home, or fading out over the card. */
    Returning,
  }

  var phase: Phase by mutableStateOf(Phase.Resting)
    internal set

  /** The ending's cream covers the backdrop: leaving is a fade, not a flight. */
  var covered: Boolean by mutableStateOf(false)
    internal set

  /** The session globe has presented its first frame. */
  var sessionReady: Boolean by mutableStateOf(false)
    internal set

  /** The lift's progress, 0 at the card, 1 at the session's rest. Read in draw only. */
  internal var progressSource: State<Float>? = null

  val progress: Float get() = progressSource?.value ?: 1f

  /** The lounge card's surface. */
  internal var cardBounds: Rect? = null

  /** The square the card seats its globe in (`cardGlobeSeat`). */
  internal var cardSeat: Rect? = null

  /** The presented backdrop's own bounds (the whole presentation). */
  internal var backdropBounds: Rect? = null

  /** The backdrop's visible rect now: the card's, grown toward [full] by [progress]. */
  fun currentRect(full: Rect): Rect = cardBounds?.let { lerp(it, full, progress) } ?: full

  /**
   * Where a night sky whose layout bounds are [own] should anchor its
   * screen-sized sky. The card's sky anchors at its own top-left; the
   * backdrop's anchors at the flight rect's top-left, so as the card lifts
   * the sky above it is exactly the card's — no star moves at lift-off.
   */
  fun skyAnchor(own: Rect?): Offset {
    if (phase == Phase.Resting || own == null || !isBackdrop(own)) return Offset.Zero
    return currentRect(backdropBounds ?: return Offset.Zero).topLeft - own.topLeft
  }

  /** Whether a view laid out at [own] is the presented backdrop (not the card). */
  fun isBackdrop(own: Rect?): Boolean {
    val backdrop = backdropBounds ?: return false
    return own != null && own.sameAs(backdrop)
  }

  internal fun reset() {
    phase = Phase.Resting
    covered = false
    sessionReady = false
    progressSource = null
    backdropBounds = null
  }

  private fun Rect.sameAs(other: Rect): Boolean =
    abs(left - other.left) < 1f && abs(top - other.top) < 1f &&
      abs(width - other.width) < 1f && abs(height - other.height) < 1f
}

/** This layout's rect in root coordinates, ignoring every ancestor's clip. */
internal fun LayoutCoordinates.unclippedRectInRoot(): Rect = Rect(positionInRoot(), size.toSize())
