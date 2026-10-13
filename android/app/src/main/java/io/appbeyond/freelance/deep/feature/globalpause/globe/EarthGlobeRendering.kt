package io.appbeyond.freelance.deep.feature.globalpause.globe

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.lerp
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.layout
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalInspectionMode
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.globalpause.LocalGlobalPauseCardLift
import io.appbeyond.freelance.deep.feature.globalpause.earth.CountryLookup
import io.appbeyond.freelance.deep.feature.globalpause.earth.EarthGeometry
import io.appbeyond.freelance.deep.feature.globalpause.earth.EarthHaloRipples
import io.appbeyond.freelance.deep.feature.globalpause.globe.earth.EarthEngine
import io.appbeyond.freelance.deep.feature.globalpause.globe.earth.EarthGlobeView
import io.appbeyond.freelance.deep.feature.globalpause.globe.earth.EarthTarget
import io.appbeyond.freelance.deep.feature.globalpause.model.PauseJoinPoint
import io.appbeyond.freelance.deep.feature.globalpause.model.PauseLiveSnapshot
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.blushPowder
import io.appbeyond.freelance.deep.theme.bloom
import io.appbeyond.freelance.deep.theme.chip
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.exhale
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.first
import java.util.Locale
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * The real Earth behind [GlobeRendering] — iOS's `EarthSceneView` /
 * `Earth3DView` on OpenGL ES 3.0 (`EARTH3D_SPIKE.md`): the glass orb, its
 * bloom, the glow where people are, sparks and rings as they arrive, the arrival
 * turn onto the member, and touch with momentum in the session.
 *
 * Provided at the app root with the [GlobeFlight] the card lift shares. The
 * 2D [PlaceholderGlobeRendering] stands in wherever the Earth can't run: in
 * previews, below OpenGL ES 3.0, or after a shader or EGL failure (logged by
 * the engine with the driver's log).
 *
 * Contract with the screens (unchanged from week 6): [Globe] fills the square
 * it is given with an orb filling [ORB_FILL_OF_SLOT] of it, transparent
 * outside. The GL orb fills only ~44% of its own view (the rest is room for
 * the bloom and the halo), so the view is drawn larger than the slot and
 * centred on it — exactly iOS's 634pt globe unit behind a 200pt card.
 */
@Stable
class EarthGlobeRendering(private val flight: GlobeFlight) : GlobeRendering {

  @Composable
  override fun NightSky(modifier: Modifier) = EarthNightSky(flight, modifier)

  @Composable
  override fun Globe(scene: GlobeScene, mode: GlobeMode, modifier: Modifier) {
    if (LocalInspectionMode.current) {
      PlaceholderGlobeRendering.Globe(scene, mode, modifier)
      return
    }
    val context = LocalContext.current
    val engine = remember { EarthEngine.get(context) }
    val status by engine.status.collectAsState()
    if (status is EarthEngine.Status.Unavailable) {
      PlaceholderGlobeRendering.Globe(scene, mode, modifier)
      return
    }
    EarthGlobe(engine, flight, scene, mode, modifier)
  }

  companion object {
    /** The orb's share of the slot a screen gives the globe (the placeholder's fill). */
    const val ORB_FILL_OF_SLOT = 0.92f
  }
}

@Composable
private fun EarthGlobe(engine: EarthEngine, flight: GlobeFlight, scene: GlobeScene, mode: GlobeMode, modifier: Modifier) {
  val target = remember(mode) {
    EarthTarget(
      frameIntervalNanos = if (mode == GlobeMode.Session) SESSION_FRAME_NANOS else CARD_FRAME_NANOS,
      renderScale = RENDER_SCALE,
    )
  }
  DisposableEffect(engine, target) {
    engine.register(target)
    onDispose { engine.unregister(target) }
  }

  // Draw only while the screen is started and nothing covers this globe: the
  // card sleeps under the landed session, the session under the ending.
  val lifecycle = LocalLifecycleOwner.current.lifecycle
  LaunchedEffect(engine, target, lifecycle) {
    combine(
      lifecycle.currentStateFlow,
      snapshotFlow { if (mode == GlobeMode.Card) flight.phase == GlobeFlight.Phase.Landed else flight.covered },
    ) { state, covered -> state.isAtLeast(Lifecycle.State.STARTED) && !covered }
      .distinctUntilChanged()
      .collect { engine.setActive(target, it) }
  }

  // The room. Every globe feeds it (idempotent), so the card's globe is the
  // one that hears the scene clear after the session has gone.
  LaunchedEffect(engine, scene) {
    snapshotFlow { SceneInputs(scene.locations, scene.unlocatedByCountry, scene.participantsByCountry, scene.homeLocation) }
      .distinctUntilChanged()
      .collect { engine.setScene(it.locations, it.unlocated, it.byCountry, it.home) }
  }

  val holder = remember { SlotHolder() }
  if (mode == GlobeMode.Session) {
    // Arrivals flare once, so only the session's globe hears them.
    LaunchedEffect(engine, scene) { scene.sparks.collect { engine.join(it.point, it.isOwn) } }
    val landing = LocalGlobalPauseCardLift.current.landingMillis
    LaunchedEffect(engine) {
      delay(landing)
      engine.beginSession()
    }
    DisposableEffect(engine) { onDispose { engine.endSession() } }
    // Latched: the lift waits for this surface's first frame once. A surface
    // rebuilt mid-sit (a lost context) must not drop the backdrop back to
    // invisible and flash the lounge through the session.
    LaunchedEffect(target) {
      target.firstFrame.first { it }
      flight.sessionReady = true
    }
  }

  val description = stringResource(R.string.pause_globe_a11y)
  Box(
    modifier
      .onGloballyPositioned {
        val rect = it.unclippedRectInRoot()
        holder.slot = rect
        if (mode == GlobeMode.Card) flight.cardSeat = rect
      }
      .clearAndSetSemantics { if (mode == GlobeMode.Session) contentDescription = description },
  ) {
    Box(
      Modifier
        .globeUnit()
        .then(if (mode == GlobeMode.Session) Modifier.flightTransform(flight, holder) else Modifier)
        .drawBehind { drawHaloBackdrop() },
    ) {
      AndroidView(
        factory = { EarthGlobeView(it, engine, target, interactive = mode == GlobeMode.Session) },
        modifier = Modifier.matchParentSize(),
      )
      RippleOverlay(engine, Modifier.matchParentSize())
    }
    if (mode == GlobeMode.Session) {
      CountryReveal(engine, Modifier.align(Alignment.TopCenter).padding(top = 12.dp))
    }
  }
}

private data class SceneInputs(
  val locations: List<PauseLiveSnapshot.GeoPoint>,
  val unlocated: Map<String, Int>,
  val byCountry: Map<String, Int>,
  val home: PauseJoinPoint?,
)

/** The slot's rect, written on layout and read while the globe flies. */
private class SlotHolder {
  var slot: Rect? = null
}

/**
 * Lays the GL view out larger than the slot and centred on it, so the orb
 * fills [EarthGlobeRendering.ORB_FILL_OF_SLOT] of the slot: the orb's radius
 * is `orbScreenRadiusFractionOfHeight` of the view's height.
 */
private fun Modifier.globeUnit(): Modifier = layout { measurable, constraints ->
  val slot = min(constraints.maxWidth, constraints.maxHeight)
  val side = (slot * EarthGlobeRendering.ORB_FILL_OF_SLOT / EarthGeometry.orbFillOfSide).roundToInt().coerceAtLeast(1)
  val placeable = measurable.measure(Constraints.fixed(side, side))
  layout(constraints.maxWidth, constraints.maxHeight) {
    placeable.place((constraints.maxWidth - side) / 2, (constraints.maxHeight - side) / 2)
  }
}

/**
 * The session globe's ride on the card lift: laid out once at its resting
 * size, it is only transformed — from the card's corner seat at progress 0 to
 * its own place at 1 — so its surface never resizes mid-flight (iOS's
 * `beginGlobeFlight` transform trick). Orb and halo scale with the view, so
 * a big render scaled down reads exactly as the card's own render did.
 */
private fun Modifier.flightTransform(flight: GlobeFlight, holder: SlotHolder): Modifier = graphicsLayer {
  val flying = flight.phase == GlobeFlight.Phase.Lifting || flight.phase == GlobeFlight.Phase.Returning
  val seat = flight.cardSeat
  val slot = holder.slot
  if (!flying || seat == null || slot == null || slot.height <= 0f) {
    scaleX = 1f
    scaleY = 1f
    translationX = 0f
    translationY = 0f
    return@graphicsLayer
  }
  val now = lerp(seat, slot, flight.progress.coerceIn(0f, 1.2f))
  val scale = now.height / slot.height
  scaleX = scale
  scaleY = scale
  translationX = now.center.x - slot.center.x
  translationY = now.center.y - slot.center.y
}

/**
 * The soft light the orb is held in — iOS `EarthSceneView`'s halo (lavender,
 * 7.45 orb radii, raised 0.18 r) and cradle (a blush ellipse 4.06 × 1.58 r,
 * 1.44 r below), dimmed to the night sky's tuned 0.25.
 */
private fun DrawScope.drawHaloBackdrop() {
  val r = EarthGeometry.orbScreenRadiusFractionOfHeight * size.height
  val c = Offset(size.width / 2f, size.height / 2f)
  val haloCentre = Offset(c.x, c.y - 0.18f * r)
  val haloRadius = r * 7.45f / 2f
  drawCircle(
    Brush.radialGradient(
      listOf(Color.lavenderMist.copy(alpha = 0.32f * BACKDROP_DIM), Color.Transparent),
      center = haloCentre,
      radius = haloRadius,
    ),
    radius = haloRadius,
    center = haloCentre,
  )
  val cradleCentre = Offset(c.x, c.y + 1.44f * r)
  val rx = r * 4.06f / 2f
  val ry = r * 1.58f / 2f
  scale(scaleX = rx / ry, scaleY = 1f, pivot = cradleCentre) {
    drawCircle(
      Brush.radialGradient(
        listOf(Color.blushPowder.copy(alpha = 0.22f * BACKDROP_DIM), Color.Transparent),
        center = cradleCentre,
        radius = ry,
      ),
      radius = ry,
      center = cradleCentre,
    )
  }
}

/**
 * The rings where people join — iOS `EarthHaloRipplesOverlay`. Projected
 * orthographically from the orb's surface with the orientation the engine
 * last rendered, on the same clock the engine stamped them with. Runs a frame
 * loop only while a ring is in flight. iOS softens the canvas with a 0.6pt
 * blur; Compose's blur is a no-op below API 31, so the strokes are a touch
 * wider instead (EARTH3D_SPIKE.md §5.3).
 */
@Composable
private fun RippleOverlay(engine: EarthEngine, modifier: Modifier) {
  val ripples by engine.ripples.collectAsState()
  val projector = remember { EarthHaloRipples(engine.rippleTuning) }
  var frameNanos by remember { mutableLongStateOf(0L) }
  LaunchedEffect(ripples.isNotEmpty()) {
    while (ripples.isNotEmpty()) frameNanos = withFrameNanos { it }
  }
  if (ripples.isEmpty()) return
  Canvas(modifier) {
    val now = frameNanos / 1e9
    val orientation = engine.orientation
    val orbRadius = EarthGeometry.orbScreenRadiusFractionOfHeight * size.height
    val centre = Offset(size.width / 2f, size.height / 2f)
    for (ripple in ripples) {
      val ring = projector.frame(ripple, now, orientation) ?: continue
      val at = Offset(centre.x + ring.x * orbRadius, centre.y - ring.y * orbRadius)
      val radius = ring.radius * orbRadius
      drawCircle(Color.lavenderMist.copy(alpha = ring.opacity), radius, at, style = Stroke(width = 1.6.dp.toPx()))
      drawCircle(
        Color.blushPowder.copy(alpha = ring.opacity * 0.5f),
        radius * 0.85f,
        at,
        style = Stroke(width = 1.dp.toPx()),
      )
    }
  }
}

/**
 * A tapped country, named for a moment at the top of the globe — iOS's reveal
 * capsule, in the member's language. A translucent cream pill stands in for
 * `.ultraThinMaterial`: there is no live blur below API 31.
 */
@Composable
private fun CountryReveal(engine: EarthEngine, modifier: Modifier) {
  val locale = LocalConfiguration.current.locales[0]
  var shown by remember { mutableStateOf<CountryLookup.Country?>(null) }
  var visible by remember { mutableStateOf(false) }
  // Bumped per tap, so tapping the same country again restarts its hold.
  var taps by remember { mutableIntStateOf(0) }
  LaunchedEffect(engine) {
    engine.reveals.collect { country ->
      shown = country
      visible = true
      taps++
    }
  }
  LaunchedEffect(taps, visible) {
    if (!visible) return@LaunchedEffect
    delay(REVEAL_HOLD_MILLIS)
    visible = false
  }
  AnimatedVisibility(
    visible = visible,
    enter = fadeIn(bloom()) + scaleIn(bloom(), initialScale = 0.95f),
    exit = fadeOut(exhale()),
    modifier = modifier,
  ) {
    val country = shown ?: return@AnimatedVisibility
    val name = Locale("", country.iso2).getDisplayCountry(locale).ifBlank { country.name }
    Text(
      name,
      style = DeepType.revealTitle,
      color = Color.deepPlum.copy(alpha = 0.85f),
      modifier = Modifier
        .background(Color.moonCream.copy(alpha = REVEAL_FILL_ALPHA), RoundedCornerShape(Dp.chip))
        .padding(horizontal = 18.dp, vertical = 8.dp),
    )
  }
}

/** EARTH3D_SPIKE.md §4.5: render at 0.6 of native, let the compositor upscale. */
private const val RENDER_SCALE = 0.6f
private const val SESSION_FRAME_NANOS = 16_666_667L
private const val CARD_FRAME_NANOS = 33_333_333L

/** iOS `NightSkyTuning.earthBackdropDim`: the cream-era halo, dimmed for the night. */
private const val BACKDROP_DIM = 0.25f
private const val REVEAL_HOLD_MILLIS = 2_400L
private const val REVEAL_FILL_ALPHA = 0.78f

@Preview(name = "Earth globe — preview stands in with the 2D globe")
@Composable
private fun EarthGlobeRenderingPreview() {
  val scene = remember {
    GlobeScene().apply {
      locations = listOf(PauseLiveSnapshot.GeoPoint(13.8f, 100.5f, 3), PauseLiveSnapshot.GeoPoint(48.9f, 2.4f, 1))
      homeLocation = PauseJoinPoint(13.8f, 100.5f)
    }
  }
  val rendering = remember { EarthGlobeRendering(GlobeFlight()) }
  DeepTheme {
    Box(Modifier.size(360.dp)) {
      rendering.NightSky(Modifier.fillMaxSize())
      rendering.Globe(scene, GlobeMode.Session, Modifier.fillMaxSize())
    }
  }
}
