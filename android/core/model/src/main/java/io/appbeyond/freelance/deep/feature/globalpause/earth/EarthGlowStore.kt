package io.appbeyond.freelance.deep.feature.globalpause.earth

import io.appbeyond.freelance.deep.feature.globalpause.model.PauseJoinPoint
import io.appbeyond.freelance.deep.feature.globalpause.model.PauseLiveSnapshot
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.floor
import kotlin.math.ln
import kotlin.math.log2
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin
import kotlin.random.Random

/**
 * One frame's glow upload: the packed sources plus the style-range counts the
 * shader loops each range with.
 *
 * [data] holds [count] sources, [FLOATS_PER_SOURCE] floats each, laid out as
 * the shader's `GlowBlock` (`vec4 glowData[128]`, two `vec4` per source):
 *
 *   positionAndIntensity = (x, y, z, intensity)
 *   radiusPacked         = (radius, whiteness, z, cosReach)
 *
 * sorted into three contiguous ranges — classic `[0, classicCount)`, orb
 * `[classicCount, classicCount + orbCount)`, shell `[…, count)`. Channel
 * meanings follow iOS's `GlowSourceGPU` exactly, with one Android change:
 * `radiusPacked.w`, a debug tag on iOS that no shader reads, carries
 * `cos(7.5 · radius)` for the classic and orb ranges — the spike's Fix B, a
 * cosine-domain reject so `accumulateGlow` pays its `acos` only for sources
 * that can reach the pixel. Shells leave it 0; their loop never reads it.
 */
class EarthGlowSnapshot(
  val data: FloatArray,
  val count: Int,
  val classicCount: Int,
  val orbCount: Int,
) {
  internal var maxOrbSigma: Float = -1f
  internal var shellExtents: FloatArray = FloatArray(0)

  /**
   * The furthest any orb or shell can light from the globe's centre, in world
   * units, or 0 when this frame has none — the shader skips both light-volume
   * loops for a ray that passes wider (spike Fix A). Exact, not a heuristic:
   * an orb seats its gaussian at most `1 + 0.05` out (the shader's elevation
   * clamp) and rejects past 7.5σ; a shell seats on the surface and rejects
   * past `R + 3w`, with `w` floored to 1.5 target pixels as the shader floors
   * it. [sigmaScale] and [radiusScale] are the frame's `orbShape.x` and breath
   * scale, which grow every volume with them.
   */
  fun lightVolumeReach(sigmaScale: Float, worldUnitsPerPixel: Float, radiusScale: Float = 1f): Float {
    var reach = 0f
    if (maxOrbSigma >= 0f) {
      reach = radiusScale * ORB_SEAT_MAX + REACH_SIGMAS * maxOf(maxOrbSigma * sigmaScale, 1e-3f)
    }
    var i = 0
    while (i < shellExtents.size) {
      val r = shellExtents[i]
      val w = maxOf(shellExtents[i + 1], 1.5f * worldUnitsPerPixel)
      reach = maxOf(reach, radiusScale + r + 3f * w)
      i += 2
    }
    return reach
  }

  companion object {
    const val FLOATS_PER_SOURCE = 8
    val Empty = EarthGlowSnapshot(FloatArray(0), 0, 0, 0)

    /** The 7.5σ reach `orbCoreHalo` rejects past. */
    private const val REACH_SIGMAS = 7.5f

    /** The orb loop's furthest seat: `p · (radius + elev)` with elev ≤ 0.05. */
    private const val ORB_SEAT_MAX = 1.05f
  }
}

/**
 * Live presence → smoothed glow sources on the orb, as iOS's
 * `EarthGlowStore`.
 *
 * Two families of light share one GPU buffer:
 * - **Steady cells**: server-clustered points (or country blobs for people the
 *   server couldn't place), lerped toward their targets so polls crossfade.
 * - **Sparks**: transient flares where someone just joined, living ~2s.
 *
 * Not thread-safe: one owner (the Earth's render thread) drives it.
 *
 * @param random the spark seed source — injectable so tests are exact.
 */
class EarthGlowStore(
  val tuning: Tuning = Tuning(),
  private val random: Random = Random.Default,
) {

  /** Every tunable constant, at its shipped default (iOS `Tuning`). */
  data class Tuning(
    val lerpTau: Float = 0.8f,
    val granularity: Granularity = Granularity.Point,
    val regionRadiusScale: Float = 1.0f,
    val pointSoftCap: Float = 6f,
    val pointBaseIntensity: Float = 0.65f,
    val pointIntensityGain: Float = 0.30f,
    val pointBaseRadius: Float = 0.034f,
    val pointRadiusGain: Float = 0.014f,
    val homeIntensity: Float = 0.9f,
    val homeRadius: Float = 0.045f,
    val homeWhiteness: Float = 0.15f,
    val homeBreathAmplitude: Float = 0.13f,
    val homeBreathRate: Float = 0.63f,
    val glowPointStyle: GlowPointStyle = GlowPointStyle.Buried,
    val sparkStyle: SparkStyle = SparkStyle.Classic,
    val sparkLife: Float = 2.0f,
    val sparkCap: Int = 8,
    val sparkRadius: Float = 0.030f,
    val sparkPeak: Float = 1.3f,
    val homeColumnHeight: Float = 1.35f,
    val sparkColumnBoost: Float = 1.5f,
    val flashPeak: Float = 1.8f,
    val flashDecay: Float = 0.12f,
    val flashRadius: Float = 0.05f,
    val shellLife: Float = 1.4f,
    val shellMaxRadius: Float = 0.42f,
    val shellThicknessBase: Float = 0.010f,
    val shellThicknessGrow: Float = 0.045f,
    val shellPeak: Float = 1.15f,
    val shellFadePower: Float = 1.5f,
    val whiteTau: Float = 0.35f,
    val twinkleLife: Float = 1.6f,
    val twinklePeak: Float = 2.2f,
    val twinkleRadius: Float = 0.022f,
    val twinkleSpeed: Float = 10f,
    val twinkleDepth: Float = 0.6f,
    val twinkleSizeJitter: Float = 0.25f,
    val twinkleDecay: Float = 0.45f,
  )

  enum class Granularity { Point, Country, Continent }

  /** Steady glow: classic surface gaussians, or one of the volumetric styles.
   * The default, [Buried], seats a light sphere on the surface and lets the
   * planet hide its under-half. */
  enum class GlowPointStyle { Classic, Orb, Dome, Buried }

  /** Join sparks: classic surface flare (+ the 2D ripple ring), 3D flash and
   * expanding shell, or a twinkling star. */
  enum class SparkStyle { Classic, FlashShell, Twinkle }

  // MARK: - Inputs

  var locations: List<PauseLiveSnapshot.GeoPoint> = emptyList()
    set(value) {
      field = value
      recomputeTargets()
    }

  var unlocatedByCountry: Map<String, Int> = emptyMap()
    set(value) {
      field = value
      recomputeTargets()
    }

  var participantsByCountry: Map<String, Int> = emptyMap()
    set(value) {
      field = value
      recomputeTargets()
    }

  var homeLocation: PauseJoinPoint? = null
    set(value) {
      field = value
      recomputeTargets()
    }

  /** Optional ceiling for the country log scale; dormant, as on iOS. */
  var globalMaxOverride: Int? = null

  // MARK: - State

  private var sources: List<SourceState> = emptyList()
  private val sparks = ArrayList<SparkState>()
  private var lastTickTime: Double? = null

  val activeSourceCount: Int get() = sources.count { it.currentIntensity > ALIVE }
  val sparkCount: Int get() = sparks.size

  /** Advances the lerps and spark ages to [time] (seconds, any monotonic clock). */
  fun tick(time: Double) {
    val prev = lastTickTime
    lastTickTime = time
    val dt = if (prev != null) min(time - prev, 0.05).toFloat() else 0f
    if (dt <= 0f) return

    val k = 1f - exp(-dt / tuning.lerpTau)
    for (s in sources) s.currentIntensity += (s.targetIntensity - s.currentIntensity) * k

    for (s in sparks) s.age += dt
    val life = effectiveSparkLife
    sparks.removeAll { it.age > life }
  }

  private val effectiveSparkLife: Float
    get() = when (tuning.sparkStyle) {
      SparkStyle.Classic -> tuning.sparkLife
      SparkStyle.FlashShell -> maxOf(tuning.sparkLife, tuning.shellLife)
      SparkStyle.Twinkle -> maxOf(tuning.sparkLife, tuning.twinkleLife)
    }

  /** Someone just joined here: flare a transient glow. */
  fun spark(lat: Float, lon: Float) {
    if (sparks.size >= tuning.sparkCap) sparks.removeAt(0)
    val region = regionFor(lat, lon)
    sparks += SparkState(
      position = region?.position ?: sphereUnitVector(lat, lon),
      radius = region?.radius ?: tuning.sparkRadius,
      seed = random.nextFloat() * 2f * PI_F,
    )
  }

  /** Drops every spark in flight — a session ending must not leave one burning. */
  fun clearSparks() = sparks.clear()

  /**
   * The renderer's upload for this frame, sorted into the three style ranges.
   * Sparks always survive the 64-source budget; past it, the steady cells
   * going dimmest are dropped first.
   */
  fun currentGpuSnapshot(): EarthGlowSnapshot {
    val classicRange = ArrayList<Packed>()
    val orbRange = ArrayList<Packed>()
    val shellRange = ArrayList<Packed>()

    for (s in sparks) {
      classicSpark(s)?.let(classicRange::add)
      if (tuning.sparkStyle == SparkStyle.FlashShell) {
        flashOrb(s)?.let(orbRange::add)
        shell(s)?.let(shellRange::add)
      }
      if (tuning.sparkStyle == SparkStyle.Twinkle) twinkleOrb(s)?.let(orbRange::add)
    }

    val sparkSlots = classicRange.size + orbRange.size + shellRange.size
    val budget = (EarthGeometry.MAX_GLOW_SOURCES - sparkSlots).coerceAtLeast(0)
    val homeBreath = 1f + tuning.homeBreathAmplitude * sin(((lastTickTime ?: 0.0) * tuning.homeBreathRate).toFloat())
    val orbStyle = tuning.glowPointStyle != GlowPointStyle.Classic
    val orbMode = when (tuning.glowPointStyle) {
      GlowPointStyle.Classic, GlowPointStyle.Orb -> 0f
      GlowPointStyle.Dome -> 1f
      GlowPointStyle.Buried -> 2f
    }
    val steady = sources
      .filter { it.currentIntensity > ALIVE }
      // Ranked by where a source is GOING: a cell that just appeared starts
      // at zero, and must not be evicted for the life of the spark that
      // introduced it.
      .sortedByDescending { maxOf(it.currentIntensity, it.targetIntensity) }
      .take(budget)
      .map { s ->
        val isHome = s.key == HOME_KEY
        val intensity = if (isHome) s.currentIntensity * homeBreath else s.currentIntensity
        if (orbStyle) {
          // Angular σ ≈ world arc σ on the unit sphere; the clamp stops a
          // region blob becoming a 0.3-unit light ball.
          Packed(
            s.position, intensity,
            s.angularRadius.coerceIn(0.018f, 0.055f),
            if (isHome) tuning.homeWhiteness else 0f,
            orbMode,
          )
        } else {
          Packed(
            s.position, intensity,
            s.angularRadius,
            if (isHome) tuning.homeWhiteness else 0f,
            if (isHome) tuning.homeColumnHeight else 1f,
          )
        }
      }

    val classic = (if (orbStyle) emptyList() else steady) + classicRange
    val orbs = (if (orbStyle) steady else emptyList()) + orbRange
    val all = classic + orbs + shellRange
    val data = FloatArray(all.size * EarthGlowSnapshot.FLOATS_PER_SOURCE)
    all.forEachIndexed { i, p ->
      val inShellRange = i >= classic.size + orbs.size
      p.writeTo(data, i * EarthGlowSnapshot.FLOATS_PER_SOURCE, withCosReach = !inShellRange)
    }
    return EarthGlowSnapshot(data, all.size, classic.size, orbs.size).also { snapshot ->
      snapshot.maxOrbSigma = orbs.maxOfOrNull { it.radius } ?: -1f
      snapshot.shellExtents = FloatArray(shellRange.size * 2).also { extents ->
        shellRange.forEachIndexed { i, shell ->
          extents[2 * i] = shell.radius
          extents[2 * i + 1] = shell.z
        }
      }
    }
  }

  // MARK: - Spark envelopes

  private fun sparkIntensity(age: Float): Float {
    val attack = smoothstep(0f, 0.12f, age)
    val decay = exp(-maxOf(0f, age - 0.12f) / 0.6f)
    return attack * decay * tuning.sparkPeak
  }

  private fun sparkWhiteness(age: Float): Float = smoothstep(0f, 0.1f, age) * exp(-age / 0.45f)

  private fun classicSpark(s: SparkState): Packed? {
    val intensity = sparkIntensity(s.age)
    if (intensity <= ALIVE) return null
    return Packed(
      s.position, intensity, s.radius, sparkWhiteness(s.age),
      1f + tuning.sparkColumnBoost * exp(-s.age / 0.45f),
    )
  }

  private fun flashOrb(s: SparkState): Packed? {
    val flash = smoothstep(0f, 0.05f, s.age) * exp(-s.age / maxOf(tuning.flashDecay, 0.01f)) * tuning.flashPeak
    if (flash <= ALIVE) return null
    return Packed(s.position, flash, tuning.flashRadius, exp(-s.age / tuning.whiteTau), 0f)
  }

  private fun twinkleOrb(s: SparkState): Packed? {
    val attack = smoothstep(0f, 0.06f, s.age)
    val decay = exp(-maxOf(0f, s.age - 0.06f) / maxOf(tuning.twinkleDecay, 0.05f))
    val tail = 1f - smoothstep(maxOf(tuning.twinkleLife - 0.3f, 0.05f), tuning.twinkleLife, s.age)
    val flicker = twinkleFlicker(s.age, s.seed)
    val intensity = attack * decay * tail * flicker * tuning.twinklePeak
    if (intensity <= ALIVE) return null
    val sigma = tuning.twinkleRadius * (1f + tuning.twinkleSizeJitter * (flicker - 1f))
    return Packed(s.position, intensity, sigma, exp(-s.age / tuning.whiteTau), 0f)
  }

  private fun twinkleFlicker(age: Float, seed: Float): Float {
    val w = age * tuning.twinkleSpeed * 2f * PI_F
    val shimmer = 0.5f * sin(w + seed) + 0.3f * sin(w * 1.73f + seed * 2.39f) + 0.2f * sin(w * 2.71f + seed * 4.63f)
    return 1f + tuning.twinkleDepth * shimmer
  }

  private fun shell(s: SparkState): Packed? {
    val u = min(s.age / maxOf(tuning.shellLife, 0.05f), 1f)
    val radius = tuning.shellMaxRadius * easeOutCubic(u)
    val thickness = tuning.shellThicknessBase + tuning.shellThicknessGrow * radius
    if (radius <= 4f * thickness) return null
    val intensity = smoothstep(0.02f, 0.14f, s.age) * (1f - u).pow(tuning.shellFadePower) * tuning.shellPeak
    if (intensity <= 0.01f) return null
    return Packed(s.position, intensity, radius, exp(-s.age / tuning.whiteTau), thickness)
  }

  // MARK: - Targets

  private fun recomputeTargets() {
    val next = ArrayList<SourceState>(locations.size + unlocatedByCountry.size + 8)

    homeLocation?.let { home ->
      next += SourceState(
        key = HOME_KEY,
        position = sphereUnitVector(home.lat, home.lon),
        angularRadius = tuning.homeRadius,
        targetIntensity = tuning.homeIntensity,
        currentIntensity = existingCurrent(HOME_KEY) ?: 0f,
      )
    }

    if (tuning.granularity == Granularity.Point) {
      appendPointSources(locations, next)
    } else {
      appendRegionSources(next)
    }

    // Country blobs: the whole world on an old server, or just the people IP
    // geolocation couldn't place on a new one.
    val countryCounts = if (locations.isEmpty() && unlocatedByCountry.isEmpty()) participantsByCountry else unlocatedByCountry
    appendCountrySources(countryCounts, next)

    // Sources whose input vanished fade out rather than pop.
    val activeKeys = next.mapTo(HashSet()) { it.key }
    for (old in sources) {
      if (old.key !in activeKeys && old.currentIntensity > ALIVE) {
        next += old.copy(targetIntensity = 0f)
      }
    }
    sources = next
  }

  private fun appendPointSources(points: List<PauseLiveSnapshot.GeoPoint>, into: MutableList<SourceState>) {
    class Cell(var lat: Float, var lon: Float, var count: Int)
    val cells = LinkedHashMap<String, Cell>()
    for (point in points) {
      if (point.count <= 0) continue
      val key = cellKey(point.lat, point.lon)
      val cell = cells[key]
      if (cell != null) {
        val oldWeight = cell.count.toFloat()
        val newWeight = point.count.toFloat()
        val total = oldWeight + newWeight
        cell.lat = (cell.lat * oldWeight + point.lat * newWeight) / total
        cell.lon = (cell.lon * oldWeight + point.lon * newWeight) / total
        cell.count += point.count
      } else {
        cells[key] = Cell(point.lat, point.lon, point.count)
      }
    }
    for ((key, cell) in cells) {
      val normalized = min(1f, log2(cell.count + 1f) / log2(tuning.pointSoftCap + 1f))
      into += SourceState(
        key = key,
        position = sphereUnitVector(cell.lat, cell.lon),
        angularRadius = tuning.pointBaseRadius + tuning.pointRadiusGain * normalized,
        targetIntensity = tuning.pointBaseIntensity + tuning.pointIntensityGain * normalized,
        currentIntensity = existingCurrent(key) ?: 0f,
      )
    }
  }

  private fun appendRegionSources(into: MutableList<SourceState>) {
    class Region(val position: Vec3, val radius: Float, var count: Int)
    val regions = LinkedHashMap<String, Region>()
    val unmatched = ArrayList<PauseLiveSnapshot.GeoPoint>()
    for (point in locations) {
      if (point.count <= 0) continue
      val resolved = regionFor(point.lat, point.lon)
      if (resolved == null) {
        unmatched += point
        continue
      }
      val region = regions[resolved.key]
      if (region != null) region.count += point.count else regions[resolved.key] = Region(resolved.position, resolved.radius, point.count)
    }
    for ((key, region) in regions) {
      val normalized = min(1f, log2(region.count + 1f) / log2(tuning.pointSoftCap + 1f))
      into += SourceState(
        key = key,
        position = region.position,
        angularRadius = region.radius,
        targetIntensity = tuning.pointBaseIntensity + tuning.pointIntensityGain * normalized,
        currentIntensity = existingCurrent(key) ?: 0f,
      )
    }
    appendPointSources(unmatched, into)
  }

  private class Region(val key: String, val position: Vec3, val radius: Float)

  private fun regionFor(lat: Float, lon: Float): Region? {
    if (tuning.granularity == Granularity.Point) return null
    val country = CountryLookup.nearestCountry(lat, lon, withinDegrees = 20f) ?: return null
    return when (tuning.granularity) {
      Granularity.Point -> null
      Granularity.Country -> Region("rg:${country.iso2}", country.unitVector, country.glowRadiusRadians * tuning.regionRadiusScale)
      Granularity.Continent -> CountryLookup.continentCenter(country.continentIso)?.let {
        Region("rg:${it.iso}", it.unitVector, it.angularRadius * tuning.regionRadiusScale)
      }
    }
  }

  private fun appendCountrySources(counts: Map<String, Int>, into: MutableList<SourceState>) {
    val globalMax = maxOf(1, globalMaxOverride ?: counts.values.maxOrNull() ?: 1)
    val logMax = ln(globalMax + 1f)
    val continentSplash = LinkedHashMap<String, Float>()
    for ((iso, count) in counts) {
      if (count <= 0) continue
      val country = CountryLookup.country(iso) ?: continue
      val intensity = smoothstep(0f, 1f, ln(count + 1f) / logMax)
      into += SourceState(
        key = iso,
        position = country.unitVector,
        angularRadius = country.glowRadiusRadians,
        targetIntensity = intensity,
        currentIntensity = existingCurrent(iso) ?: 0f,
      )
      if (country.isTiny) {
        continentSplash[country.continentIso] = (continentSplash[country.continentIso] ?: 0f) + intensity * 0.35f
      }
    }
    for ((continent, splash) in continentSplash) {
      val center = CountryLookup.continentCenter(continent) ?: continue
      val key = "__CONT__$continent"
      into += SourceState(
        key = key,
        position = center.unitVector,
        angularRadius = center.angularRadius,
        targetIntensity = min(1f, splash),
        currentIntensity = existingCurrent(key) ?: 0f,
      )
    }
  }

  private fun existingCurrent(key: String): Float? = sources.firstOrNull { it.key == key }?.currentIntensity

  /** Seeds every current at its target — previews show the full glow at once. */
  fun settleAtTargets() {
    for (s in sources) s.currentIntensity = s.targetIntensity
  }

  // MARK: - Nodes

  private data class SourceState(
    val key: String,
    val position: Vec3,
    val angularRadius: Float,
    val targetIntensity: Float,
    var currentIntensity: Float,
  )

  private class SparkState(val position: Vec3, val radius: Float, val seed: Float) {
    var age: Float = 0f
  }

  /** One source in the GPU layout, before it is written to the float buffer. */
  private class Packed(
    val position: Vec3,
    val intensity: Float,
    val radius: Float,
    val whiteness: Float,
    val z: Float,
  ) {
    fun writeTo(out: FloatArray, at: Int, withCosReach: Boolean) {
      out[at] = position.x
      out[at + 1] = position.y
      out[at + 2] = position.z
      out[at + 3] = intensity
      out[at + 4] = radius
      out[at + 5] = whiteness
      out[at + 6] = z
      out[at + 7] = if (withCosReach) cosReach(radius) else 0f
    }
  }

  companion object {
    private const val HOME_KEY = "home"
    private const val ALIVE = 0.003f

    /** The 7.5-radius reach `accumulateGlow` rejects past. */
    const val REACH_RADII = 7.5f

    /**
     * `cos(7.5 · max(r, 0.01) + `[COS_REACH_MARGIN]`)`, or −1 when that reach
     * passes the antipode: the threshold below which `accumulateGlow` may
     * skip a source before its `acos`. The margin keeps the skip strictly
     * looser than the shader's own `x > 7.5` test, which stays the one that
     * decides — so float rounding at the boundary can never drop a source
     * the original kept (the Codex review of the port).
     */
    fun cosReach(radius: Float): Float {
      val reach = REACH_RADII * maxOf(radius, 0.01f) + COS_REACH_MARGIN
      return if (reach >= PI_F) -1f else cos(reach)
    }

    /** Radians of slack on the cosine pre-reject. */
    const val COS_REACH_MARGIN = 1e-3f

    /** iOS's 0.25° quantised cell key — half the server's 1° cluster grid. */
    internal fun cellKey(lat: Float, lon: Float): String =
      "pt:${(lat * 4f).roundHalfAway()}|${(lon * 4f).roundHalfAway()}"

    /** Swift's `.rounded()`: half away from zero (Kotlin's `roundToInt` rounds half up). */
    private fun Float.roundHalfAway(): Int = if (this >= 0f) floor(this + 0.5f).toInt() else -floor(-this + 0.5f).toInt()
  }
}
