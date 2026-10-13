package io.appbeyond.freelance.deep.feature.globalpause.globe

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.feature.globalpause.model.PauseJoinPoint
import io.appbeyond.freelance.deep.feature.globalpause.model.PauseLiveSnapshot
import io.appbeyond.freelance.deep.shared.components.rememberReduceMotion
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.blushPowder
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.nightHorizon
import io.appbeyond.freelance.deep.theme.nightZenith
import io.appbeyond.freelance.deep.theme.peachCloud
import io.appbeyond.freelance.deep.theme.softLilac
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt
import kotlin.random.Random

/**
 * The week-6 stand-in behind [GlobeRendering]: a flat, dotted orb that still
 * tells the truth about the room — every located participant glows where they
 * are, the member's own point warms, and each arrival rings out as it lands.
 * It is deliberately modest; week 7's GLES Earth replaces it wholesale and
 * this stays as the fallback for devices that can't run that.
 *
 * Projection is orthographic around a turning centre: in the card it drifts
 * west to east, about a turn every two minutes; in the session it eases round
 * to the member's own longitude and rests there (iOS's arrival turn, minus
 * the minute it takes — the placeholder has nothing to show on the way).
 * Reduce motion holds it still.
 */
object PlaceholderGlobeRendering : GlobeRendering {

  @Composable
  override fun NightSky(modifier: Modifier) = PlaceholderNightSky(modifier)

  @Composable
  override fun Globe(scene: GlobeScene, mode: GlobeMode, modifier: Modifier) =
    PlaceholderGlobe(scene, mode, modifier)
}

/** A dark plum sky with a lilac horizon and a scatter of still stars. */
@Composable
private fun PlaceholderNightSky(modifier: Modifier) {
  val stars = remember { stars() }
  Canvas(
    modifier
      .background(Brush.verticalGradient(listOf(Color.nightZenith, Color.nightHorizon)))
      .clearAndSetSemantics {},
  ) {
    drawRect(
      Brush.verticalGradient(
        0.55f to Color.Transparent,
        1f to Color.softLilac.copy(alpha = HORIZON_GLOW),
      ),
    )
    for (star in stars) {
      drawCircle(
        color = Color.moonCream.copy(alpha = star.alpha),
        radius = star.radius * density,
        center = Offset(star.x * size.width, star.y * size.height),
      )
    }
  }
}

private data class Star(val x: Float, val y: Float, val radius: Float, val alpha: Float)

private fun stars(): List<Star> {
  // Seeded, so the sky is the same sky on every screen and every launch.
  val random = Random(STAR_SEED)
  return List(STAR_COUNT) {
    Star(
      x = random.nextFloat(),
      y = random.nextFloat(),
      radius = 0.5f + random.nextFloat() * 0.9f,
      alpha = 0.15f + random.nextFloat() * 0.5f,
    )
  }
}

/** One arrival ringing out, stamped with its birth on the frame clock. */
private data class LiveSpark(val spark: GlobeScene.Spark, val bornNanos: Long)

@Composable
private fun PlaceholderGlobe(scene: GlobeScene, mode: GlobeMode, modifier: Modifier) {
  val reduceMotion = rememberReduceMotion()

  // The card drifts; the session turns home and rests.
  val drift = rememberInfiniteTransition(label = "globe-drift")
  val driftLon by drift.animateFloat(
    initialValue = 0f,
    targetValue = 360f,
    animationSpec = infiniteRepeatable(tween(DRIFT_MILLIS, easing = LinearEasing), RepeatMode.Restart),
    label = "globe-drift-lon",
  )
  val home = scene.homeLocation
  val restLon = remember { Animatable(DEFAULT_LON) }
  LaunchedEffect(home?.lon, mode) {
    val target = home?.lon ?: DEFAULT_LON
    if (reduceMotion) restLon.snapTo(target) else restLon.animateTo(target, tween(ARRIVAL_MILLIS))
  }
  val centreLon = when {
    mode == GlobeMode.Session -> restLon.value
    reduceMotion -> DEFAULT_LON
    else -> driftLon
  }

  // Arrivals ring for a couple of seconds each, on the frame clock.
  val sparks = remember { mutableStateListOf<LiveSpark>() }
  var frameNanos by remember { mutableLongStateOf(0L) }
  LaunchedEffect(scene) {
    scene.sparks.collect { spark ->
      sparks += LiveSpark(spark, withFrameNanos { it })
    }
  }
  LaunchedEffect(sparks.isNotEmpty()) {
    while (sparks.isNotEmpty()) {
      frameNanos = withFrameNanos { it }
      sparks.removeAll { frameNanos - it.bornNanos > SPARK_NANOS }
    }
  }

  Box(modifier.clearAndSetSemantics {}) {
    Canvas(Modifier.fillMaxSize()) {
      val radius = min(size.width, size.height) / 2f * ORB_FILL
      val centre = Offset(size.width / 2f, size.height / 2f)
      val projection = Projection(centre, radius, CENTRE_LAT, centreLon)

      drawHalo(centre, radius)
      drawOrb(centre, radius)
      drawLattice(projection)
      drawLights(projection, scene.locations, home)
      for (live in sparks) {
        val age = ((frameNanos - live.bornNanos).coerceAtLeast(0L)).toFloat() / SPARK_NANOS
        drawSpark(projection, live.spark, age.coerceIn(0f, 1f))
      }
    }
  }
}

/** Orthographic projection around ([lat0], [lon0]), in degrees. */
private class Projection(val centre: Offset, val radius: Float, lat0: Float, lon0: Float) {
  private val phi0 = lat0.toRadians()
  private val lambda0 = lon0.toRadians()

  /** The point on screen and how squarely it faces us (0 at the limb), or
   * null on the far side. */
  fun project(lat: Float, lon: Float): Pair<Offset, Float>? {
    val phi = lat.toRadians()
    val dLambda = lon.toRadians() - lambda0
    val facing = sin(phi0) * sin(phi) + cos(phi0) * cos(phi) * cos(dLambda)
    if (facing <= 0f) return null
    val x = cos(phi) * sin(dLambda)
    val y = cos(phi0) * sin(phi) - sin(phi0) * cos(phi) * cos(dLambda)
    return Offset(centre.x + x * radius, centre.y - y * radius) to facing
  }
}

private fun Float.toRadians(): Float = (this * PI / 180.0).toFloat()

private fun DrawScope.drawHalo(centre: Offset, radius: Float) {
  drawCircle(
    brush = Brush.radialGradient(
      0.7f to Color.lavenderMist.copy(alpha = HALO_ALPHA),
      1f to Color.Transparent,
      center = centre,
      radius = radius * HALO_SCALE,
    ),
    radius = radius * HALO_SCALE,
    center = centre,
  )
}

private fun DrawScope.drawOrb(centre: Offset, radius: Float) {
  drawCircle(
    brush = Brush.radialGradient(
      0f to Color.lavenderMist.copy(alpha = 0.55f),
      0.6f to Color.deepPlum.copy(alpha = 0.92f),
      1f to Color.nightZenith,
      center = Offset(centre.x - radius * 0.35f, centre.y - radius * 0.4f),
      radius = radius * 1.6f,
    ),
    radius = radius,
    center = centre,
  )
}

/** A dotted lattice every 15°, dimming toward the limb — enough to read as a
 * turning world without drawing any continent it doesn't know. */
private fun DrawScope.drawLattice(projection: Projection) {
  var lat = -75f
  while (lat <= 75f) {
    var lon = -180f
    while (lon < 180f) {
      projection.project(lat, lon)?.let { (point, facing) ->
        drawCircle(
          color = Color.moonCream.copy(alpha = LATTICE_ALPHA * facing),
          radius = LATTICE_DOT * density,
          center = point,
        )
      }
      lon += LATTICE_STEP
    }
    lat += LATTICE_STEP
  }
}

private fun DrawScope.drawLights(
  projection: Projection,
  locations: List<PauseLiveSnapshot.GeoPoint>,
  home: PauseJoinPoint?,
) {
  for (location in locations) {
    val (point, facing) = projection.project(location.lat, location.lon) ?: continue
    val glow = projection.radius * LIGHT_SCALE * sqrt(location.count.toFloat()).coerceAtMost(4f)
    drawCircle(
      brush = Brush.radialGradient(
        0f to Color.peachCloud.copy(alpha = 0.9f * facing),
        1f to Color.Transparent,
        center = point,
        radius = glow,
      ),
      radius = glow,
      center = point,
    )
  }
  home?.let { projection.project(it.lat, it.lon) }?.let { (point, facing) ->
    val glow = projection.radius * HOME_SCALE
    drawCircle(
      brush = Brush.radialGradient(
        0f to Color.blushPowder.copy(alpha = facing),
        1f to Color.Transparent,
        center = point,
        radius = glow,
      ),
      radius = glow,
      center = point,
    )
    drawCircle(Color.moonCream.copy(alpha = facing), radius = 2.2f * density, center = point)
  }
}

private fun DrawScope.drawSpark(projection: Projection, spark: GlobeScene.Spark, age: Float) {
  val (point, facing) = projection.project(spark.point.lat, spark.point.lon) ?: return
  val reach = projection.radius * (if (spark.isOwn) SPARK_REACH_OWN else SPARK_REACH)
  drawCircle(
    color = Color.moonCream.copy(alpha = (1f - age) * facing),
    radius = reach * age,
    center = point,
    style = Stroke(width = 1.5f * density),
  )
  drawCircle(
    color = Color.blushPowder.copy(alpha = (1f - age) * facing),
    radius = 3f * density * (1f - age * 0.5f),
    center = point,
  )
}

private const val ORB_FILL = 0.92f
private const val CENTRE_LAT = 15f
private const val DEFAULT_LON = 100f
private const val DRIFT_MILLIS = 120_000
private const val ARRIVAL_MILLIS = 4_000
private const val HALO_SCALE = 1.22f
private const val HALO_ALPHA = 0.22f
private const val LATTICE_STEP = 15f
private const val LATTICE_DOT = 0.9f
private const val LATTICE_ALPHA = 0.32f
private const val LIGHT_SCALE = 0.05f
private const val HOME_SCALE = 0.09f
private const val SPARK_REACH = 0.14f
private const val SPARK_REACH_OWN = 0.22f
private const val SPARK_NANOS = 2_400_000_000L
private const val HORIZON_GLOW = 0.22f
private const val STAR_SEED = 7
private const val STAR_COUNT = 90

@Preview(name = "Placeholder globe — session")
@Composable
private fun PlaceholderGlobePreview() {
  val scene = remember {
    GlobeScene().apply {
      locations = listOf(
        PauseLiveSnapshot.GeoPoint(13.8f, 100.5f, 3),
        PauseLiveSnapshot.GeoPoint(35.0f, 135.8f, 1),
        PauseLiveSnapshot.GeoPoint(-1.3f, 36.8f, 1),
        PauseLiveSnapshot.GeoPoint(48.9f, 2.4f, 1),
      )
      homeLocation = PauseJoinPoint(13.8f, 100.5f)
    }
  }
  DeepTheme {
    Box(Modifier.size(360.dp)) {
      PlaceholderGlobeRendering.NightSky(Modifier.fillMaxSize())
      PlaceholderGlobeRendering.Globe(scene, GlobeMode.Session, Modifier.fillMaxSize())
    }
  }
}
