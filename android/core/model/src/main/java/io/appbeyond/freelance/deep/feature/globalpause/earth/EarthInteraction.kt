package io.appbeyond.freelance.deep.feature.globalpause.earth

import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sqrt
import kotlin.math.tan

/**
 * The orb's orientation: drag-driven yaw and pitch, momentum, the idle
 * Lissajous drift, the arrival turn, and the tap raycast — iOS's
 * `EarthInteraction`.
 *
 * North-up model: orientation is DERIVED from two scalars — [pitch] about the
 * camera's X axis, then [yaw] about the globe's polar Y axis — so roll is
 * structurally impossible and no drag sequence can tumble the world sideways.
 * Pitch is clamped short of ±90° so it never gimbal-flips.
 *
 * Time is whatever monotonic clock the owner's frames run on, in seconds; the
 * renderer is the only caller of [orientationMatrix], and nothing here reads
 * a clock of its own (iOS's rule — a second clock corrupts `dt`).
 *
 * Two Android changes, both from `EARTH3D_SPIKE.md` §5.2:
 * - **Release velocity is measured, not assumed.** iOS multiplies the last
 *   move delta by 60 ("~60Hz touch delivery"); Android digitisers report at
 *   120–240 Hz and batch samples, which would throw a flick at double speed.
 *   Moves carry their event time, and release velocity is the angle swept
 *   over the last [VELOCITY_WINDOW] seconds of samples.
 * - **The tap slop is the platform's**, passed in by the view.
 *
 * Not thread-safe: the render thread owns it, and touch events are posted to
 * that thread.
 */
class EarthInteraction(val tuning: Tuning = Tuning()) {

  data class Tuning(
    /** Damping per 60Hz frame — "globe on bearings" friction. */
    val damping: Float = 0.92f,
    /** 1.0 = arc-length-correct: the surface under the finger tracks it. */
    val dragGain: Float = 1.0f,
    val pitchLimitDegrees: Float = 85f,
    val idleAfterSeconds: Double = 2.0,
    /** Idle drift, radians per second. */
    val idleDriftSpeed: Float = 0.05f,
  )

  enum class SpinState { Free, Held }

  /** Intent, not the gate's current value: held from the moment it's asked. */
  var spinState: SpinState = SpinState.Free
    private set

  var yaw: Float = 0f
    private set
  var pitch: Float = 0f
    private set

  /** 0…1 on self-driven motion (drift + post-flick momentum). Drags pass. */
  var driveGate: Float = 1f
    private set

  private class Ease(val from: Float, val to: Float, val duration: Double) {
    var startTime: Double? = null
  }

  private class Turn(
    val fromYaw: Float,
    val fromPitch: Float,
    val toYaw: Float,
    val toPitch: Float,
    val duration: Double,
  ) {
    var startTime: Double? = null
  }

  private var gateAnimation: Ease? = null
  private var orientAnimation: Turn? = null

  /** Post-release momentum, radians per second (yaw, pitch). */
  private var momentumYaw = 0f
  private var momentumPitch = 0f
  private var lastFrameTime: Double? = null
  private var lastInteractionTime = 0.0

  private var touchStartX = 0f
  private var touchStartY = 0f
  private var lastTouchX = 0f
  private var lastTouchY = 0f
  private var touching = false

  /** Recent (time, cumulative yaw, cumulative pitch) samples for release velocity. */
  private val samples = ArrayDeque<FloatArray>()
  private val sampleTimes = ArrayDeque<Double>()

  val isTurning: Boolean get() = orientAnimation != null
  val momentum: Pair<Float, Float> get() = momentumYaw to momentumPitch

  private val pitchLimit: Float get() = tuning.pitchLimitDegrees * DEG

  private fun clampPitch(value: Float): Float = value.coerceIn(-pitchLimit, pitchLimit)

  // MARK: - Spin gate

  /** Eases self-driven motion to a stop and holds it. Idempotent. */
  fun decelerateToRest(overSeconds: Double = 5.0) {
    spinState = SpinState.Held
    gateAnimation?.let { if (it.to == 0f) return }
    if (gateAnimation == null && driveGate == 0f) return
    gateAnimation = Ease(driveGate, 0f, overSeconds)
  }

  /** Eases the gate back open; retargets seamlessly mid-deceleration. */
  fun resumeSpin(overSeconds: Double = 3.0) {
    spinState = SpinState.Free
    gateAnimation?.let { if (it.to == 1f) return }
    if (gateAnimation == null && driveGate == 1f) return
    gateAnimation = Ease(driveGate, 1f, overSeconds)
  }

  // MARK: - Turn to a place

  /**
   * The arrival: keep turning for [overSeconds] and come to rest with the
   * point facing the camera, north up. Yaw is taken FORWARD — the way idle
   * drift turns — and at least [minimumTurns] whole revolutions, so every
   * arrival reads the same; `minimumTurns = 0` re-aims one already in flight.
   */
  fun settle(latDeg: Float, lonDeg: Float, overSeconds: Double, minimumTurns: Float = 1f) {
    val targetPitch = clampPitch(latDeg * DEG)
    val shortest = ieeeRemainder(-lonDeg * DEG - yaw, 2f * PI_F)
    val ahead = if (shortest < 0f) shortest + 2f * PI_F else shortest
    orientAnimation = Turn(yaw, pitch, yaw + ahead + minimumTurns * 2f * PI_F, targetPitch, overSeconds)
    // The turn owns the view: a leftover flick must not replay after it.
    momentumYaw = 0f
    momentumPitch = 0f
  }

  /** Abandons an arrival in flight (leaving the session mid-turn). */
  fun cancelTurn() {
    orientAnimation = null
  }

  // MARK: - Orientation

  /** Advances to [time] and returns the composed rotation: axial tilt × orientation. */
  fun orientationMatrix(time: Double): Mat4 {
    advance(time)
    return currentOrientationMatrix()
  }

  /** The composed rotation as last advanced, WITHOUT stepping the simulation. */
  fun currentOrientationMatrix(): Mat4 = Mat4.rotationZ(EarthGeometry.AXIAL_TILT) * orientation().toMat4()

  private fun orientation(): Quat =
    Quat.axisAngle(Vec3(1f, 0f, 0f), pitch) * Quat.axisAngle(Vec3(0f, 1f, 0f), yaw)

  private fun advance(time: Double) {
    val prev = lastFrameTime
    val dt = if (prev != null) (time - prev).toFloat() else 0f
    lastFrameTime = time

    gateAnimation?.let { anim ->
      val start = anim.startTime ?: time.also { anim.startTime = it }
      if (anim.duration <= 0.0) {
        driveGate = anim.to
        gateAnimation = null
      } else {
        val t = ((time - start) / anim.duration).coerceIn(0.0, 1.0).toFloat()
        val eased = t * t * (3f - 2f * t)
        driveGate = anim.from + (anim.to - anim.from) * eased
        if (t >= 1f) gateAnimation = null
      }
    }

    orientAnimation?.let { anim ->
      val start = anim.startTime ?: time.also { anim.startTime = it }
      if (anim.duration <= 0.0) {
        yaw = anim.toYaw
        pitch = anim.toPitch
        orientAnimation = null
        lastInteractionTime = time
      } else {
        val t = ((time - start) / anim.duration).coerceIn(0.0, 1.0).toFloat()
        // Ease OUT: the globe arrives already spinning and coasts onto the target.
        val eased = t * (2f - t)
        yaw = anim.fromYaw + (anim.toYaw - anim.fromYaw) * eased
        pitch = anim.fromPitch + (anim.toPitch - anim.fromPitch) * eased
        if (t >= 1f) {
          orientAnimation = null
          lastInteractionTime = time
        }
      }
      return
    }

    if (hypot(momentumYaw, momentumPitch) > 0.0001f) {
      yaw += momentumYaw * dt * driveGate
      val target = pitch + momentumPitch * dt * driveGate
      val clamped = clampPitch(target)
      if (clamped != target) momentumPitch = 0f
      pitch = clamped
      // Frame-rate independent: per-60Hz-frame damping as a per-second rate.
      val decay = tuning.damping.pow(60f).pow(dt)
      momentumYaw *= decay
      momentumPitch *= decay
      // A closing gate bleeds the momentum store too, so a flick thrown while
      // decelerating can't sit behind the gate and replay on resume.
      if (driveGate < 1f && dt > 0f) {
        val bleed = maxOf(driveGate, 0f).pow(dt * 60f)
        momentumYaw *= bleed
        momentumPitch *= bleed
      }
    } else {
      momentumYaw = 0f
      momentumPitch = 0f
    }

    val idleFor = time - lastInteractionTime
    if (!touching && idleFor > tuning.idleAfterSeconds && dt > 0f && driveGate > 0f) {
      val strength = min(1f, ((idleFor - tuning.idleAfterSeconds) / 1.5).toFloat())
      yaw += tuning.idleDriftSpeed * dt * strength * driveGate
      pitch = clampPitch(pitch + cos(time.toFloat() * 0.097f) * 0.04f * 0.097f * dt * strength * driveGate)
    }

    // Yaw is unbounded under drift; wrap it while no turn owns its endpoints.
    yaw = ieeeRemainder(yaw, 2f * PI_F)
  }

  // MARK: - Touch

  /** Radians per pixel: the orb's on-screen radius is the normaliser. */
  private fun radiansPerPixel(viewHeight: Float): Float =
    tuning.dragGain / maxOf(1f, EarthGeometry.orbScreenRadiusFractionOfHeight * viewHeight)

  fun touchBegan(x: Float, y: Float, eventTime: Double) {
    touching = true
    touchStartX = x
    touchStartY = y
    lastTouchX = x
    lastTouchY = y
    momentumYaw = 0f
    momentumPitch = 0f
    samples.clear()
    sampleTimes.clear()
    record(eventTime)
    lastInteractionTime = lastFrameTime ?: 0.0
  }

  /** One move sample — call once per historical sample too, oldest first. */
  fun touchMoved(x: Float, y: Float, eventTime: Double, viewHeight: Float) {
    if (!touching) return
    val dx = x - lastTouchX
    val dy = y - lastTouchY
    lastTouchX = x
    lastTouchY = y
    // A DRAGGING finger cancels a turn in flight; a mere tap must not.
    orientAnimation = null

    val k = radiansPerPixel(viewHeight)
    val newPitch = clampPitch(pitch + dy * k)
    // The APPLIED pitch: releasing pinned at the clamp stores no ghost flick.
    val dPitch = newPitch - pitch
    yaw += dx * k
    pitch = newPitch
    accumulatedYaw += dx * k
    accumulatedPitch += dPitch
    record(eventTime)
    lastInteractionTime = lastFrameTime ?: 0.0
  }

  /**
   * The finger lifted. Returns where it tapped, as lat/lon on the globe, when
   * it moved less than [tapSlop] pixels and landed on the orb; else null.
   */
  fun touchEnded(
    x: Float,
    y: Float,
    eventTime: Double,
    viewWidth: Float,
    viewHeight: Float,
    tapSlop: Float,
  ): LatLon? {
    if (!touching) return null
    touching = false
    val (vYaw, vPitch) = releaseVelocity(eventTime)
    momentumYaw = vYaw
    momentumPitch = vPitch
    samples.clear()
    sampleTimes.clear()
    lastInteractionTime = lastFrameTime ?: 0.0

    val travelled = hypot(x - touchStartX, y - touchStartY)
    if (travelled >= tapSlop) return null
    return raycastLatLon(x, y, viewWidth, viewHeight, currentOrientationMatrix())
  }

  fun touchCancelled() {
    touching = false
    samples.clear()
    sampleTimes.clear()
  }

  private var accumulatedYaw = 0f
  private var accumulatedPitch = 0f

  private fun record(time: Double) {
    samples.addLast(floatArrayOf(accumulatedYaw, accumulatedPitch))
    sampleTimes.addLast(time)
    while (sampleTimes.size > 2 && time - sampleTimes.first() > VELOCITY_WINDOW) {
      samples.removeFirst()
      sampleTimes.removeFirst()
    }
  }

  /**
   * Radians per second over the samples inside the window before [releaseTime].
   * A finger that held still before lifting (its last move older than the
   * window) throws nothing.
   */
  internal fun releaseVelocity(releaseTime: Double): Pair<Float, Float> {
    if (sampleTimes.isEmpty()) return 0f to 0f
    val lastTime = sampleTimes.last()
    if (releaseTime - lastTime > VELOCITY_WINDOW) return 0f to 0f
    var firstIndex = 0
    while (firstIndex < sampleTimes.size - 1 && lastTime - sampleTimes[firstIndex] > VELOCITY_WINDOW) firstIndex++
    val span = lastTime - sampleTimes[firstIndex]
    if (span < MIN_VELOCITY_SPAN) return 0f to 0f
    val first = samples[firstIndex]
    val last = samples.last()
    return ((last[0] - first[0]) / span).toFloat() to ((last[1] - first[1]) / span).toFloat()
  }

  companion object {
    /** Release velocity looks back this far (seconds), as `VelocityTracker`'s horizon. */
    const val VELOCITY_WINDOW = 0.1
    /** Shorter spans are a tap's jitter, not a flick. */
    const val MIN_VELOCITY_SPAN = 0.008

    /**
     * Screen point → lat/lon on the orb, or null off it. The camera sits at
     * (0, 0, +distance) looking down −Z; the hit is taken back through the
     * inverse orientation into the sphere's own frame. iOS `handleTap`.
     */
    fun raycastLatLon(x: Float, y: Float, viewWidth: Float, viewHeight: Float, orientation: Mat4): LatLon? {
      if (viewWidth <= 0f || viewHeight <= 0f) return null
      val ndcX = (x / viewWidth) * 2f - 1f
      val ndcY = 1f - (y / viewHeight) * 2f
      val aspect = viewWidth / viewHeight
      val tanHalfFov = tan(EarthGeometry.CAMERA_FOV_Y * 0.5f)
      val dir = Vec3(ndcX * aspect * tanHalfFov, ndcY * tanHalfFov, -1f).normalized()
      val origin = Vec3(0f, 0f, EarthGeometry.CAMERA_DISTANCE)
      val r = EarthGeometry.SPHERE_RADIUS
      val b = dir dot origin
      val c = (origin dot origin) - r * r
      val disc = b * b - c
      if (disc < 0f) return null
      val t = -b - sqrt(disc)
      if (t <= 0f) return null
      val hit = origin + dir * t
      // The orientation is a pure rotation: its inverse is its transpose.
      val local = orientation.transposed().transformDirection(hit).normalized()
      return latLonOf(local)
    }
  }
}
