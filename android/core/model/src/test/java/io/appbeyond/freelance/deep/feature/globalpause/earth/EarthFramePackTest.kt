package io.appbeyond.freelance.deep.feature.globalpause.earth

import org.junit.jupiter.api.Test
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sqrt
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

/**
 * Ported behaviour from Deep/Deep/Features/GlobalPause/Earth3D/EarthRenderer.swift
 * (`makeUniforms`, the glow-count clamps in `draw`, and `breathingCurve`) and
 * EarthRendererTypes.swift (`EarthUniforms`). iOS has no tests for these; these are new,
 * written from the iOS behaviour.
 *
 * What it guards: the 52-float per-frame uniform block lands each value in the std140
 * slot the shader reads, the range counts can never point the shader past the 64-source
 * buffer, and the breath is the 4 s / 6 s physiological sigh.
 */
class EarthFramePackTest {

  private fun pack(
    glow: EarthGlowSnapshot,
    time: Float = 2f,
    aspect: Float = 0.75f,
    heightPx: Int = 900,
    orientation: Mat4 = Mat4.Identity,
  ): FloatArray {
    val out = FloatArray(EarthFrame.FLOATS) { Float.NaN }
    EarthFrame.pack(out, time, aspect, heightPx, orientation, glow, EarthTuning())
    return out
  }

  private fun snapshot(count: Int, classic: Int, orbs: Int) =
    EarthGlowSnapshot(FloatArray(count * EarthGlowSnapshot.FLOATS_PER_SOURCE), count, classic, orbs)

  @Test
  fun fiftyTwoFloatsInStd140Order() {
    assertEquals(52, EarthFrame.FLOATS)
    assertEquals(208, EarthFrame.BYTES)

    val orientation = Mat4.rotationZ(EarthGeometry.AXIAL_TILT) * Quat.axisAngle(Vec3(1f, 0f, 0f), 0.3f).toMat4()
    val out = pack(snapshot(5, 2, 2), time = 2f, aspect = 0.75f, heightPx = 900, orientation = orientation)

    // inverseViewProj at 0..15
    val inv = Mat4(out.copyOfRange(0, 16))
    val roundTrip = inv * EarthGeometry.viewProjection(0.75f)
    for (i in 0 until 16) assertEquals(Mat4.Identity.m[i], roundTrip.m[i], 1e-4f, "invVP·VP element $i")
    // cameraPosition
    assertEquals(listOf(0f, 0f, 8.5f, 1f), out.slice(16..19))
    // sphereOrientation at 20..35
    assertEquals(orientation.m.toList(), out.slice(20..35))
    // sunDirection, normalised, w = 0
    val len = sqrt(0.45f * 0.45f + 0.55f * 0.55f + 0.7f * 0.7f)
    assertEquals(-0.45f / len, out[36], 1e-6f)
    assertEquals(0.55f / len, out[37], 1e-6f)
    assertEquals(0.7f / len, out[38], 1e-6f)
    assertEquals(0f, out[39])
    // params = (time, breath, classic, count)
    assertEquals(2f, out[40])
    assertEquals(0.5f, out[41], 1e-6f)
    assertEquals(2f, out[42])
    assertEquals(5f, out[43])
    // sphereData
    assertEquals(listOf(0f, 0f, 0f, 1f), out.slice(44..47))
    // atmosphereData = (radius, strength, orb count, world units per pixel)
    assertEquals(1.06f, out[48])
    assertEquals(0.1f, out[49])
    assertEquals(2f, out[50])
    assertEquals(EarthGeometry.worldUnitsPerPixel(900), out[51])
  }

  @Test
  fun countsAreClampedToTheSixtyFourSourceBuffer() {
    val overClassic = pack(snapshot(80, 70, 10))
    assertEquals(64f, overClassic[42])
    assertEquals(64f, overClassic[43])
    assertEquals(0f, overClassic[50])

    val overOrbs = pack(snapshot(70, 10, 60))
    assertEquals(10f, overOrbs[42])
    assertEquals(64f, overOrbs[43])
    assertEquals(54f, overOrbs[50])

    val empty = pack(EarthGlowSnapshot.Empty)
    assertEquals(0f, empty[42])
    assertEquals(0f, empty[43])
    assertEquals(0f, empty[50])
  }

  @Test
  fun aShortBufferIsRefused() {
    assertFailsWith<IllegalArgumentException> {
      EarthFrame.pack(FloatArray(51), 0f, 1f, 600, Mat4.Identity, EarthGlowSnapshot.Empty, EarthTuning())
    }
  }

  @Test
  fun breathingCurveIsAFourSecondInhaleAndSixSecondExhale() {
    fun breath(t: Float) = EarthFrame.breathingCurve(t, 4f, 6f)
    assertEquals(0f, breath(0f), 1e-6f)
    assertEquals(0.5f, breath(2f), 1e-6f)
    assertEquals(1f, breath(4f), 1e-6f)
    assertEquals(0.5f, breath(7f), 1e-6f)
    assertEquals(0f, breath(10f), 1e-6f)
    assertEquals(0.5f - 0.5f * cos(PI.toFloat() / 4f), breath(1f), 1e-6f)
  }

  @Test
  fun breathingCurveEasesSymmetricallyAndRepeatsEveryTenSeconds() {
    fun breath(t: Float) = EarthFrame.breathingCurve(t, 4f, 6f)
    for (x in listOf(0.3f, 1f, 1.7f, 3.2f)) {
      assertEquals(1f, breath(x) + breath(4f - x), 1e-5f, "inhale at $x")
    }
    for (x in listOf(0.5f, 2f, 2.9f)) {
      assertEquals(1f, breath(4f + x) + breath(10f - x), 1e-5f, "exhale at $x")
    }
    for (t in listOf(0.4f, 3.3f, 6.1f, 9.7f)) {
      assertEquals(breath(t), breath(t + 10f), 1e-4f)
      assertEquals(breath(t), breath(t + 120f), 1e-4f)
    }
    for (i in 0..100) {
      val b = breath(i * 0.1f)
      assertTrue(b in 0f..1f, "breath $b at ${i * 0.1f}")
    }
  }

  @Test
  fun breathingCurveFloorsDegenerateDurations() {
    // Both floored to 0.1 s: a 0.2 s period.
    assertEquals(1f, EarthFrame.breathingCurve(0.1f, 0f, -3f), 1e-5f)
    assertEquals(0f, EarthFrame.breathingCurve(0.2f, 0f, -3f), 1e-4f)
  }
}
