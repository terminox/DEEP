package io.appbeyond.freelance.deep.feature.globalpause.earth

import kotlin.math.PI
import kotlin.math.cos

/**
 * The per-frame `EarthUniforms` block: 13 `vec4` — 52 floats, 208 bytes —
 * in the std140 order of the shader's block and iOS's `EarthUniforms`
 * struct:
 *
 *   mat4 inverseViewProj; vec4 cameraPosition; mat4 sphereOrientation;
 *   vec4 sunDirection; vec4 params; vec4 sphereData; vec4 atmosphereData;
 *
 * `params` = (time, breath 0…1, classic count, total count);
 * `sphereData` = (centre xyz, radius);
 * `atmosphereData` = (atmosphere radius, its strength, orb count,
 * world units per target pixel).
 */
object EarthFrame {
  const val FLOATS = 52
  const val BYTES = FLOATS * 4

  /**
   * Fills [into] for one target.
   *
   * @param aspect the target's width / height.
   * @param targetHeightPx the target's height in RENDERED pixels — the shell
   *   ring's anti-alias floor is 1.5 of these.
   */
  fun pack(
    into: FloatArray,
    time: Float,
    aspect: Float,
    targetHeightPx: Int,
    orientation: Mat4,
    glow: EarthGlowSnapshot,
    tuning: EarthTuning,
  ) {
    require(into.size >= FLOATS) { "The frame block needs $FLOATS floats" }
    val invViewProj = EarthGeometry.viewProjection(aspect).inverse()
    val sun = Vec3(tuning.sunX, tuning.sunY, tuning.sunZ).normalized()
    val breath = breathingCurve(time, tuning.breathInhaleSeconds, tuning.breathExhaleSeconds)
    val count = minOf(glow.count, EarthGeometry.MAX_GLOW_SOURCES)
    val classic = minOf(glow.classicCount, count)
    val orbs = minOf(glow.orbCount, maxOf(count - glow.classicCount, 0))

    invViewProj.m.copyInto(into, 0)
    put(into, 16, 0f, 0f, EarthGeometry.CAMERA_DISTANCE, 1f)
    orientation.m.copyInto(into, 20)
    put(into, 36, sun.x, sun.y, sun.z, 0f)
    put(into, 40, time, breath, classic.toFloat(), count.toFloat())
    put(into, 44, 0f, 0f, 0f, EarthGeometry.SPHERE_RADIUS)
    put(
      into, 48,
      EarthGeometry.ATMOSPHERE_RADIUS,
      tuning.atmosphereStrength,
      orbs.toFloat(),
      EarthGeometry.worldUnitsPerPixel(targetHeightPx),
    )
  }

  private fun put(into: FloatArray, at: Int, x: Float, y: Float, z: Float, w: Float) {
    into[at] = x
    into[at + 1] = y
    into[at + 2] = z
    into[at + 3] = w
  }

  /**
   * The physiological sigh: a cosine-eased rise over [inhale] seconds and
   * fall over [exhale] (4s / 6s by default), 0…1. iOS's `breathingCurve`.
   */
  fun breathingCurve(time: Float, inhale: Float, exhale: Float): Float {
    val i = maxOf(inhale, 0.1f)
    val e = maxOf(exhale, 0.1f)
    val period = i + e
    // Swift's truncatingRemainder — the sign of the dividend, like Kotlin's %.
    val t = time % period
    return if (t < i) {
      0.5f - 0.5f * cos(t / i * PI.toFloat())
    } else {
      0.5f + 0.5f * cos((t - i) / e * PI.toFloat())
    }
  }
}
