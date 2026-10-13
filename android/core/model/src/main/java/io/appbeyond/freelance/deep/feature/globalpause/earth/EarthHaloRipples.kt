package io.appbeyond.freelance.deep.feature.globalpause.earth

import kotlin.math.cos

/**
 * The ring that rings out where someone joins, drawn over the orb rather than
 * in the shader — iOS's `EarthHaloRipples`.
 *
 * Times are seconds on ONE clock — whatever the caller stamps [emit] with
 * must be what it hands [tick] and [frame] (iOS's rule: the renderer's
 * relative frame clock must never leak in).
 *
 * Not thread-safe: the owner confines it to one thread and publishes
 * [active] snapshots to whoever draws.
 */
class EarthHaloRipples(val tuning: Tuning = Tuning()) {

  data class Tuning(
    /** Cap on simultaneous rings — ambient, not a leaderboard. */
    val globalCap: Int = 8,
    /** A second ring this soon and this close to a recent one is suppressed. */
    val spatialCooldown: Double = 0.3,
    val lifetime: Double = 1.2,
    val cooldownAngleDegrees: Float = 3f,
    /** Ring sweep, as fractions of the orb's on-screen radius. */
    val ringStartRadius: Float = 0.05f,
    val ringEndRadius: Float = 0.32f,
    val ringOpacity: Float = 0.7f,
  )

  /** One ring: a sphere-local unit vector, and when it started. */
  data class Ripple(val position: Vec3, val startedAt: Double)

  /** What one ring looks like at one moment, in a view centred on the orb. */
  data class RingFrame(
    /** Offset from the orb's centre, in orb radii (y up). */
    val x: Float,
    val y: Float,
    /** Ring radius, in orb radii. */
    val radius: Float,
    val opacity: Float,
  )

  private val _active = ArrayList<Ripple>()
  val active: List<Ripple> get() = _active.toList()

  private val recent = ArrayList<Ripple>()

  fun emit(latDeg: Float, lonDeg: Float, time: Double) {
    val position = sphereUnitVector(latDeg, lonDeg)
    val cooldownCos = cos(tuning.cooldownAngleDegrees * DEG)
    recent.removeAll { time - it.startedAt > tuning.spatialCooldown }
    if (recent.any { (it.position dot position) > cooldownCos }) return
    if (_active.size >= tuning.globalCap) _active.removeAt(0)
    val ripple = Ripple(position, time)
    _active += ripple
    recent += ripple
  }

  /** Every ring at once, cooldown memory included. */
  fun clear() {
    _active.clear()
    recent.clear()
  }

  fun tick(time: Double) {
    val cutoff = time - tuning.lifetime
    _active.removeAll { it.startedAt < cutoff }
  }

  /**
   * Where and how [ripple] draws at [time] under [orientation] (tilt ×
   * orientation, sphere-local → world), orthographically projected onto the
   * view plane; null while it hasn't started, has expired, or faces away.
   */
  fun frame(ripple: Ripple, time: Double, orientation: Mat4): RingFrame? {
    val age = time - ripple.startedAt
    if (age < 0.0 || age > tuning.lifetime) return null
    val world = orientation.transformDirection(ripple.position)
    // Back-hemisphere rings read as ghosts.
    if (world.z < -0.1f) return null
    val visibility = smoothstep(-0.1f, 0.25f, world.z)
    val progress = (age / tuning.lifetime).toFloat()
    val radius = mix(tuning.ringStartRadius, tuning.ringEndRadius, easeOutCubic(progress))
    val opacity = mix(tuning.ringOpacity, 0f, progress) * visibility
    return RingFrame(world.x, world.y, radius, opacity)
  }
}
