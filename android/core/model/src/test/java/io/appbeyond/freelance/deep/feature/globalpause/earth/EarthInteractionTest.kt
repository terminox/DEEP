package io.appbeyond.freelance.deep.feature.globalpause.earth

import org.junit.jupiter.api.Test
import kotlin.math.abs
import kotlin.math.min
import kotlin.math.pow
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Ported behaviour from Deep/Deep/Features/GlobalPause/Earth3D/EarthInteraction.swift.
 * iOS has no tests for it; these are new, written from the iOS behaviour plus the two
 * documented Android changes (release velocity measured from event times, the platform's
 * tap slop).
 *
 * What it guards: the globe's feel — a flick's momentum decays at the same rate at any
 * frame rate, the pitch never passes ±85°, a held globe stays held, the idle drift waits
 * its turn, and the arrival turn always goes forward and lands centred.
 */
class EarthInteractionTest {

  private val width = 800f
  private val height = 1000f
  private val radiansPerPixel = 1f / (EarthGeometry.orbScreenRadiusFractionOfHeight * height)
  private val pitchLimit = 85f * DEG

  /** Steps the frame clock over (from, to] at [hz]. */
  private fun EarthInteraction.frames(from: Double, to: Double, hz: Int) {
    val steps = Math.round((to - from) * hz).toInt()
    for (i in 1..steps) orientationMatrix(from + i.toDouble() / hz)
  }

  /**
   * A drag of (dx, dy) pixels over [seconds], one move per touch report at [hz], lifted
   * [liftAfter] seconds after the last move. Event times start at [start].
   */
  private fun EarthInteraction.drag(
    dx: Float,
    dy: Float,
    seconds: Double,
    hz: Int,
    start: Double = 0.0,
    liftAfter: Double = 0.004,
  ): LatLon? {
    val x0 = 400f
    val y0 = 500f
    touchBegan(x0, y0, start)
    val n = Math.round(seconds * hz).toInt()
    for (i in 1..n) {
      val f = i.toFloat() / n
      touchMoved(x0 + dx * f, y0 + dy * f, start + i.toDouble() / hz, height)
    }
    return touchEnded(x0 + dx, y0 + dy, start + seconds + liftAfter, width, height, tapSlop = 8f)
  }

  private fun assertRelative(expected: Float, actual: Float, relative: Float = 1e-3f) {
    assertTrue(abs(actual - expected) <= abs(expected) * relative, "expected $expected, was $actual")
  }

  // MARK: - Release velocity (Android: measured, not ×60)

  /** Same sweep, same duration, twice the report rate: the same throw. iOS's ×60 would double it. */
  @Test
  fun releaseVelocityIsMeasuredFromEventTimes() {
    val expected = 100f * radiansPerPixel / 0.05f
    for (hz in listOf(60, 120, 240)) {
      val interaction = EarthInteraction()
      interaction.orientationMatrix(0.0)
      interaction.drag(dx = 100f, dy = 0f, seconds = 0.05, hz = hz)
      assertRelative(expected, interaction.momentum.first)
      assertEquals(0f, interaction.momentum.second)
    }
  }

  @Test
  fun aFingerThatHeldStillBeforeLiftingThrowsNothing() {
    val interaction = EarthInteraction()
    interaction.orientationMatrix(0.0)
    interaction.drag(dx = 100f, dy = 40f, seconds = 0.05, hz = 120, liftAfter = 0.15)
    assertEquals(0f to 0f, interaction.momentum)
  }

  /** Pinned at the pitch clamp, the finger's last strokes apply no pitch, so none is thrown. */
  @Test
  fun releasingPinnedAtTheClampThrowsNoPitch() {
    val interaction = EarthInteraction()
    interaction.orientationMatrix(0.0)
    interaction.touchBegan(400f, 100f, 0.0)
    // 500 px over the first 0.1 s is ~2.2 rad of pitch: pinned at 85° by ~0.07 s. The
    // finger keeps pushing for another 0.1 s — the whole velocity window — while pinned.
    for (i in 1..24) {
      val y = if (i <= 12) 100f + 500f * i / 12f else 600f + 200f * (i - 12) / 12f
      interaction.touchMoved(400f, y, i / 120.0, height)
    }
    interaction.touchEnded(400f, 800f, 0.2 + 0.004, width, height, tapSlop = 8f)
    assertEquals(pitchLimit, interaction.pitch, 1e-6f)
    assertEquals(0f, interaction.momentum.second)
  }

  // MARK: - Tap vs drag

  @Test
  fun aTapReturnsWhereItLandedAndThrowsNothing() {
    val interaction = EarthInteraction()
    interaction.orientationMatrix(0.0)
    interaction.touchBegan(width / 2f, height / 2f, 0.0)
    val hit = assertNotNull(interaction.touchEnded(width / 2f + 2f, height / 2f + 1f, 0.08, width, height, tapSlop = 8f))
    assertEquals(0f, hit.lat, 1f)
    assertEquals(0f, hit.lon, 1f)
    assertEquals(0f to 0f, interaction.momentum)
  }

  @Test
  fun aDragReturnsNull() {
    val interaction = EarthInteraction()
    interaction.orientationMatrix(0.0)
    assertNull(interaction.drag(dx = 60f, dy = 0f, seconds = 0.05, hz = 120))
  }

  @Test
  fun aTapOffTheOrbReturnsNull() {
    val interaction = EarthInteraction()
    interaction.orientationMatrix(0.0)
    interaction.touchBegan(5f, 5f, 0.0)
    assertNull(interaction.touchEnded(5f, 5f, 0.05, width, height, tapSlop = 8f))
  }

  // MARK: - Momentum

  @Test
  fun momentumDecaysByDampingToTheSixtiethPerSecondAtAnyFrameRate() {
    val perSecond = 0.92f.pow(60f)
    val after = listOf(60, 120, 90).map { hz ->
      val interaction = EarthInteraction()
      interaction.orientationMatrix(0.0)
      interaction.drag(dx = 100f, dy = 30f, seconds = 0.05, hz = 120)
      val (yaw0, pitch0) = interaction.momentum
      interaction.frames(0.0, 1.0, hz)
      val (yaw1, pitch1) = interaction.momentum
      assertRelative(yaw0 * perSecond, yaw1, 1e-3f)
      assertRelative(pitch0 * perSecond, pitch1, 1e-3f)
      yaw1
    }
    assertRelative(after[0], after[1], 1e-3f)
    assertRelative(after[0], after[2], 1e-3f)
  }

  @Test
  fun aVerticalFlickRestsAtThePoleWithItsPitchMomentumKilled() {
    for (sign in listOf(1f, -1f)) {
      val interaction = EarthInteraction()
      interaction.orientationMatrix(0.0)
      interaction.drag(dx = 30f, dy = sign * 200f, seconds = 0.05, hz = 120)
      assertTrue(abs(interaction.momentum.second) > 1f)
      interaction.frames(0.0, 1.5, 60)
      assertEquals(sign * pitchLimit, interaction.pitch, 1e-6f)
      assertEquals(0f, interaction.momentum.second)
    }
  }

  @Test
  fun aFlickDiesWithTheGateAndNeverReplaysOnResume() {
    val interaction = EarthInteraction()
    interaction.orientationMatrix(0.0)
    interaction.decelerateToRest(overSeconds = 1.0)
    interaction.drag(dx = 150f, dy = 0f, seconds = 0.05, hz = 120)
    assertTrue(interaction.momentum.first > 1f)

    interaction.frames(0.0, 1.5, 60)
    assertEquals(0f, interaction.driveGate)
    assertEquals(0f to 0f, interaction.momentum)

    // Held: no drift, no momentum, however long it sits.
    val held = interaction.yaw
    interaction.frames(1.5, 10.0, 60)
    assertEquals(held, interaction.yaw)

    interaction.resumeSpin(overSeconds = 1.0)
    interaction.frames(10.0, 10.5, 60)
    assertEquals(0f to 0f, interaction.momentum)
  }

  // MARK: - Idle drift

  @Test
  fun idleDriftWaitsThenRampsOverOneAndAHalfSeconds() {
    val interaction = EarthInteraction()
    interaction.orientationMatrix(0.0)
    interaction.frames(0.0, 2.0, 60)
    assertEquals(0f, interaction.yaw)
    assertEquals(0f, interaction.pitch)

    // Step frame by frame and check each increment against 0.05 · dt · strength.
    var t = 2.0
    var checked = 0
    while (t < 5.0) {
      val next = t + 1.0 / 60.0
      val before = interaction.yaw
      interaction.orientationMatrix(next)
      val strength = min(1.0, (next - 2.0) / 1.5).toFloat()
      val expected = 0.05f * (next - t).toFloat() * strength
      assertEquals(expected, interaction.yaw - before, 2e-6f, "at t=$next")
      t = next
      checked++
    }
    assertTrue(checked > 100)
  }

  @Test
  fun idleDriftWaitsForTheLastInteraction() {
    val interaction = EarthInteraction()
    interaction.orientationMatrix(0.0)
    interaction.frames(0.0, 5.0, 60)
    interaction.drag(dx = 0f, dy = 0f, seconds = 0.0, hz = 60, start = 5.0)
    val afterTouch = interaction.yaw
    interaction.frames(5.0, 7.0, 60)
    assertEquals(afterTouch, interaction.yaw, 1e-6f)
    interaction.frames(7.0, 8.0, 60)
    assertTrue(interaction.yaw > afterTouch)
  }

  /** Android: a finger resting on the globe is not idle, however long it rests. */
  @Test
  fun aRestingFingerHoldsOffTheDrift() {
    val interaction = EarthInteraction()
    interaction.orientationMatrix(0.0)
    interaction.touchBegan(400f, 500f, 0.0)
    interaction.frames(0.0, 6.0, 60)
    assertEquals(0f, interaction.yaw)
  }

  // MARK: - Settle

  @Test
  fun settleTurnsForwardAtLeastOneLapAndLandsCentred() {
    val interaction = EarthInteraction()
    interaction.orientationMatrix(0.0)
    interaction.settle(15.87f, 100.99f, overSeconds = 4.0)
    assertTrue(interaction.isTurning)

    val startYaw = interaction.yaw
    var previous = startYaw
    for (i in 0..240) {
      interaction.orientationMatrix(i / 60.0)
      assertTrue(interaction.yaw >= previous, "yaw went back at frame $i")
      previous = interaction.yaw
    }
    assertFalse(interaction.isTurning)
    val turned = interaction.yaw - startYaw
    // Forward to −lon, plus one whole revolution.
    val ahead = (-100.99f * DEG).let { if (it < 0f) it + 2f * PI_F else it }
    assertEquals(2f * PI_F + ahead, turned, 1e-4f)
    assertEquals(15.87f * DEG, interaction.pitch, 1e-5f)
    assertCentred(interaction, 15.87f, 100.99f)
  }

  @Test
  fun minimumTurnsZeroReAimsWithoutAnotherLap() {
    val interaction = EarthInteraction()
    interaction.orientationMatrix(0.0)
    interaction.settle(15.87f, 100.99f, overSeconds = 4.0)
    for (i in 0..120) interaction.orientationMatrix(i / 60.0)
    assertTrue(interaction.isTurning)

    // Mid-flight correction to Tokyo.
    val midYaw = interaction.yaw
    interaction.settle(35.7f, 139.7f, overSeconds = 1.0, minimumTurns = 0f)
    var previous = midYaw
    // Through the landing frame only: the next free frame wraps yaw back into (−π, π].
    for (i in 120..180) {
      interaction.orientationMatrix(i / 60.0)
      assertTrue(interaction.yaw >= previous)
      previous = interaction.yaw
    }
    assertFalse(interaction.isTurning)
    val turned = interaction.yaw - midYaw
    assertTrue(turned >= 0f && turned < 2f * PI_F, "turned $turned")
    assertCentred(interaction, 35.7f, 139.7f)
  }

  @Test
  fun settleDiscardsALeftoverFlick() {
    val interaction = EarthInteraction()
    interaction.orientationMatrix(0.0)
    interaction.drag(dx = 150f, dy = 50f, seconds = 0.05, hz = 120)
    assertTrue(interaction.momentum.first > 0f)
    interaction.settle(0f, 0f, overSeconds = 1.0)
    assertEquals(0f to 0f, interaction.momentum)
  }

  @Test
  fun aDragCancelsTheTurnButATapDoesNot() {
    val tapped = EarthInteraction()
    tapped.orientationMatrix(0.0)
    tapped.settle(-33.9f, 151.2f, overSeconds = 2.0)
    tapped.orientationMatrix(0.0)
    tapped.orientationMatrix(0.5)
    tapped.touchBegan(400f, 500f, 0.5)
    tapped.touchEnded(401f, 500f, 0.6, width, height, tapSlop = 8f)
    assertTrue(tapped.isTurning)
    for (i in 31..120) tapped.orientationMatrix(i / 60.0)
    assertFalse(tapped.isTurning)
    assertCentred(tapped, -33.9f, 151.2f)

    val dragged = EarthInteraction()
    dragged.orientationMatrix(0.0)
    dragged.settle(-33.9f, 151.2f, overSeconds = 2.0)
    dragged.orientationMatrix(0.5)
    dragged.touchBegan(400f, 500f, 0.5)
    dragged.touchMoved(420f, 500f, 0.51, height)
    assertFalse(dragged.isTurning)
  }

  private fun assertCentred(interaction: EarthInteraction, lat: Float, lon: Float) {
    val hit = assertNotNull(
      EarthInteraction.raycastLatLon(width / 2f, height / 2f, width, height, interaction.currentOrientationMatrix()),
    )
    val gap = (sphereUnitVector(lat, lon) - sphereUnitVector(hit.lat, hit.lon)).length
    assertTrue(gap < 1e-3f, "($lat, $lon) centred as $hit")
  }

  // MARK: - Spin gate

  @Test
  fun decelerateSmoothstepsTheGateAndIsIdempotent() {
    val interaction = EarthInteraction()
    interaction.orientationMatrix(0.0)
    interaction.decelerateToRest(overSeconds = 4.0)
    assertEquals(EarthInteraction.SpinState.Held, interaction.spinState)
    assertEquals(1f, interaction.driveGate)

    interaction.orientationMatrix(0.0) // anchors the ease
    interaction.orientationMatrix(1.0) // t = 0.25 → smoothstep 0.15625
    assertEquals(1f - 0.15625f, interaction.driveGate, 1e-6f)

    interaction.decelerateToRest(overSeconds = 4.0) // no retarget
    interaction.orientationMatrix(2.0)
    assertEquals(0.5f, interaction.driveGate, 1e-6f)

    interaction.orientationMatrix(4.0)
    assertEquals(0f, interaction.driveGate)
    interaction.decelerateToRest() // already held: nothing to ease
    interaction.orientationMatrix(5.0)
    assertEquals(0f, interaction.driveGate)
  }

  @Test
  fun resumeRetargetsFromMidDecelerationAndIsIdempotent() {
    val interaction = EarthInteraction()
    interaction.orientationMatrix(0.0)
    interaction.decelerateToRest(overSeconds = 4.0)
    interaction.orientationMatrix(0.0)
    interaction.orientationMatrix(2.0)
    assertEquals(0.5f, interaction.driveGate, 1e-6f)

    interaction.resumeSpin(overSeconds = 2.0)
    assertEquals(EarthInteraction.SpinState.Free, interaction.spinState)
    interaction.orientationMatrix(2.0) // anchors from 0.5
    interaction.orientationMatrix(3.0) // t = 0.5 → halfway from 0.5 to 1
    assertEquals(0.75f, interaction.driveGate, 1e-6f)

    interaction.resumeSpin(overSeconds = 2.0) // no retarget
    interaction.orientationMatrix(4.0)
    assertEquals(1f, interaction.driveGate)
    interaction.resumeSpin()
    interaction.orientationMatrix(4.5)
    assertEquals(1f, interaction.driveGate)
  }

  @Test
  fun aZeroLengthEaseSnaps() {
    val interaction = EarthInteraction()
    interaction.orientationMatrix(0.0)
    interaction.decelerateToRest(overSeconds = 0.0)
    interaction.orientationMatrix(0.016)
    assertEquals(0f, interaction.driveGate)
  }
}
