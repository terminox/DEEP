package io.appbeyond.freelance.deep.feature.globalpause.globe

import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import io.appbeyond.freelance.deep.feature.globalpause.model.PauseJoinPoint
import io.appbeyond.freelance.deep.feature.globalpause.model.PauseLiveSnapshot
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow

/*
 * THE GLOBE SLOT.
 *
 * Every Global Pause screen that shows the Earth — the card in Fuku's Lounge
 * and the live session behind the meditation — draws it through
 * [LocalGlobeRendering], never by naming a renderer. `MainActivity` provides
 * [EarthGlobeRendering], the OpenGL ES Earth (`EARTH3D_SPIKE.md`), which
 * itself falls back to [PlaceholderGlobeRendering], the flat 2D orb, wherever
 * the Earth can't run. The local's default is the placeholder, so previews
 * stay hermetic.
 *
 * What the renderer draws from is [GlobeScene], one instance for the whole
 * app (owned in `MainActivity`), so the card and the session share one globe
 * — the precondition for the card lift, where the card's globe *becomes* the
 * session's backdrop without a cut.
 *
 * iOS counterparts: `GlobalPauseEarthScene` (the scene), `EarthSceneView` /
 * `Earth3DView` (the renderer), `NightSkyBackground` (the backdrop).
 */

/** Where the globe is seated. The renderer owns the geometry of each. */
enum class GlobeMode {
  /** Resting in the lounge card: large, cropped by the card's bottom-right
   * corner, slowly turning. iOS's `CardGlobeSeat`. */
  Card,

  /** Behind the live meditation: whole, centred, turning to rest on the
   * member's own location. */
  Session,
}

/**
 * Draws the Global Pause Earth and its night sky. Implementations must be
 * hermetic to their inputs — everything they show comes from the [GlobeScene]
 * they are handed — and must fill the bounds their modifier gives them.
 */
@Stable
interface GlobeRendering {

  /** The starry backdrop the card, and the session, sit on. Full-bleed. */
  @Composable
  fun NightSky(modifier: Modifier)

  /**
   * The globe itself, in [mode]. Fills its bounds; the caller decides where
   * those bounds are (the card seats it past its corner, the session centres
   * it). Transparent outside the orb, so the [NightSky] shows around it.
   */
  @Composable
  fun Globe(scene: GlobeScene, mode: GlobeMode, modifier: Modifier)
}

/** The renderer every Global Pause screen draws through. */
val LocalGlobeRendering = staticCompositionLocalOf<GlobeRendering> { PlaceholderGlobeRendering }

/**
 * What the globe shows: where the room is, where the member is, and who just
 * arrived. The session screen feeds it from the live poll; the renderer only
 * reads it.
 *
 * The Android twin of iOS's `GlobalPauseEarthScene` + `EarthGlowStore` inputs,
 * minus everything the renderer owns (interaction, momentum, ripples' own
 * timing).
 */
@Stable
class GlobeScene {

  /** Per-country glow — only for a server that sends no locations. */
  var participantsByCountry: Map<String, Int> by mutableStateOf(emptyMap())

  /** Located participants, server-clustered. */
  var locations: List<PauseLiveSnapshot.GeoPoint> by mutableStateOf(emptyList())

  /** Participants the server couldn't place, by country — drawn at their
   * country's centroid (`CountryLookup`). */
  var unlocatedByCountry: Map<String, Int> by mutableStateOf(emptyMap())

  /** The member's own point: the globe turns here and seats a home glow. */
  var homeLocation: PauseJoinPoint? by mutableStateOf(null)

  /** One arrival to flare. [isOwn] is the member's own, at the landing. */
  data class Spark(val point: PauseJoinPoint, val isOwn: Boolean)

  private val _sparks = MutableSharedFlow<Spark>(
    extraBufferCapacity = SPARK_BUFFER,
    onBufferOverflow = BufferOverflow.DROP_OLDEST,
  )

  /** Arrivals to flare, as they come. Not replayed. */
  val sparks: SharedFlow<Spark> = _sparks.asSharedFlow()

  fun enqueueJoins(points: List<PauseJoinPoint>) {
    points.forEach { _sparks.tryEmit(Spark(it, isOwn = false)) }
  }

  fun enqueueOwnJoin(point: PauseJoinPoint) {
    _sparks.tryEmit(Spark(point, isOwn = true))
  }

  /** The world's lights are the session's alone: everything goes dark. */
  fun clear() {
    participantsByCountry = emptyMap()
    locations = emptyList()
    unlocatedByCountry = emptyMap()
    homeLocation = null
  }

  private companion object {
    const val SPARK_BUFFER = 32
  }
}
