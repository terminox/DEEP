package io.appbeyond.freelance.deep.feature.globalpause.earth

import org.junit.jupiter.api.Test
import kotlin.math.cos
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Ported behaviour from Deep/Deep/Features/GlobalPause/Earth3D/EarthHaloRipples.swift
 * (`EarthHaloRipples` and the projection inside `EarthHaloRipplesOverlay`). iOS has no
 * tests for it; these are new, written from the iOS behaviour.
 *
 * What it guards: a burst of same-city joins reads as one ring rather than a strobe, a
 * flood never stacks more than eight, rings expire on time, and each one sweeps and fades
 * on the curve the iOS overlay draws — and never ghosts through from the far side.
 */
class EarthHaloRipplesTest {

  @Test
  fun aNearbyRepeatInsideTheCooldownIsSuppressed() {
    val ripples = EarthHaloRipples()
    ripples.emit(0f, 0f, time = 0.0)
    ripples.emit(1f, 0f, time = 0.1) // 1° away, 0.1 s later
    assertEquals(1, ripples.active.size)
  }

  @Test
  fun aFartherOrLaterRepeatRings() {
    val ripples = EarthHaloRipples()
    ripples.emit(0f, 0f, time = 0.0)
    ripples.emit(5f, 0f, time = 0.1) // 5° away: its own ring
    assertEquals(2, ripples.active.size)
    ripples.emit(0.5f, 0f, time = 0.35) // close to the first, but its cooldown has lapsed
    assertEquals(3, ripples.active.size)
  }

  @Test
  fun theCooldownAngleIsThreeDegrees() {
    val near = EarthHaloRipples()
    near.emit(0f, 0f, time = 0.0)
    near.emit(2.9f, 0f, time = 0.0)
    assertEquals(1, near.active.size)

    val far = EarthHaloRipples()
    far.emit(0f, 0f, time = 0.0)
    far.emit(3.1f, 0f, time = 0.0)
    assertEquals(2, far.active.size)
  }

  @Test
  fun capOfEightEvictsTheOldest() {
    val ripples = EarthHaloRipples()
    for (i in 0 until 9) ripples.emit(0f, i * 20f, time = i * 0.01)
    val active = ripples.active
    assertEquals(8, active.size)
    assertEquals(0.01, active.first().startedAt, 1e-9)
    assertEquals(0.08, active.last().startedAt, 1e-9)
  }

  @Test
  fun tickRemovesExpiredRings() {
    val ripples = EarthHaloRipples()
    ripples.emit(0f, 0f, time = 0.0)
    ripples.emit(0f, 90f, time = 0.5)
    ripples.tick(1.2)
    assertEquals(2, ripples.active.size) // the first is exactly 1.2 s old: still drawing
    ripples.tick(1.21)
    assertEquals(1, ripples.active.size)
    ripples.tick(1.75)
    assertEquals(0, ripples.active.size)
  }

  @Test
  fun clearForgetsTheCooldownToo() {
    val ripples = EarthHaloRipples()
    ripples.emit(0f, 0f, time = 0.0)
    ripples.clear()
    assertEquals(0, ripples.active.size)
    ripples.emit(0f, 0f, time = 0.05)
    assertEquals(1, ripples.active.size)
  }

  @Test
  fun aRingSweepsOnEaseOutCubicAndFadesLinearly() {
    val ripples = EarthHaloRipples()
    ripples.emit(0f, 0f, time = 10.0)
    val ripple = ripples.active.single()

    val start = assertNotNull(ripples.frame(ripple, 10.0, Mat4.Identity))
    assertEquals(0.05f, start.radius, 1e-6f)
    assertEquals(0.7f, start.opacity, 1e-6f)
    assertEquals(0f, start.x, 1e-6f)
    assertEquals(0f, start.y, 1e-6f)

    for (progress in listOf(0.1f, 0.25f, 0.5f, 0.8f)) {
      val f = assertNotNull(ripples.frame(ripple, 10.0 + 1.2 * progress, Mat4.Identity))
      val inv = 1f - progress
      assertEquals(0.05f + 0.27f * (1f - inv * inv * inv), f.radius, 1e-5f)
      assertEquals(0.7f * inv, f.opacity, 1e-5f)
    }

    val end = assertNotNull(ripples.frame(ripple, 11.2, Mat4.Identity))
    assertEquals(0.32f, end.radius, 1e-6f)
    assertEquals(0f, end.opacity, 1e-6f)

    assertNull(ripples.frame(ripple, 11.25, Mat4.Identity)) // expired
    assertNull(ripples.frame(ripple, 9.9, Mat4.Identity)) // not started
  }

  /** The offset is the ring's world x/y in orb radii — the orthographic projection, y up. */
  @Test
  fun aRingSitsAtItsProjectedPlace() {
    val ripples = EarthHaloRipples()
    ripples.emit(30f, 20f, time = 0.0)
    val f = assertNotNull(ripples.frame(ripples.active.single(), 0.3, Mat4.Identity))
    val p = sphereUnitVector(30f, 20f)
    assertEquals(p.x, f.x, 1e-6f)
    assertEquals(p.y, f.y, 1e-6f)
    assertTrue(f.y > 0f)
  }

  @Test
  fun theFarSideIsCulledAndTheLimbFades() {
    val ripples = EarthHaloRipples()
    ripples.emit(0f, 180f, time = 0.0)
    ripples.emit(0f, 95f, time = 0.0)
    ripples.emit(0f, 80f, time = 0.0)
    val (back, nearLimb, front) = ripples.active

    assertNull(ripples.frame(back, 0.0, Mat4.Identity))

    // z = cos 95° ≈ −0.087: just inside the −0.1 cull, almost invisible.
    val z95 = cos(95f * DEG)
    val limb = assertNotNull(ripples.frame(nearLimb, 0.0, Mat4.Identity))
    assertEquals(0.7f * smoothstep(-0.1f, 0.25f, z95), limb.opacity, 1e-6f)

    val z80 = cos(80f * DEG)
    val seen = assertNotNull(ripples.frame(front, 0.0, Mat4.Identity))
    assertEquals(0.7f * smoothstep(-0.1f, 0.25f, z80), seen.opacity, 1e-6f)
  }

  /** The orientation turns the ring with the globe: spun 180°, the far side faces us. */
  @Test
  fun frameFollowsTheOrientation() {
    val ripples = EarthHaloRipples()
    ripples.emit(0f, 180f, time = 0.0)
    val spun = Quat.axisAngle(Vec3(0f, 1f, 0f), PI_F).toMat4()
    val f = assertNotNull(ripples.frame(ripples.active.single(), 0.0, spun))
    assertEquals(0.7f, f.opacity, 1e-5f)
    assertEquals(0f, f.x, 1e-5f)

    // A quarter turn short of that puts it on the limb, culled just past it.
    val edgeOn = Quat.axisAngle(Vec3(0f, 1f, 0f), PI_F / 2f - 0.2f).toMat4()
    assertTrue(edgeOn.transformDirection(sphereUnitVector(0f, 180f)).z < -0.1f)
    assertNull(ripples.frame(ripples.active.single(), 0.0, edgeOn))
  }
}
