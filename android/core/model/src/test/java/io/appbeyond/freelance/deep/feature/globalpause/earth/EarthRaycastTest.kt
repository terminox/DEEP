package io.appbeyond.freelance.deep.feature.globalpause.earth

import org.junit.jupiter.api.Test
import kotlin.math.acos
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Ported behaviour from Deep/Deep/Features/GlobalPause/Earth3D/EarthInteraction.swift
 * (`handleTap`, `settle`, `orientationMatrix`). iOS has no tests for these; these are new,
 * written from the iOS behaviour.
 *
 * What it guards: a tap lands on the lat/lon the shader drew under the finger, and the
 * arrival turn really does centre its target. iOS's `settle` comment claims the axial tilt,
 * composed as a Z rotation, leaves the front axis fixed so the target stays centred after
 * tilt; this verifies that claim.
 */
class EarthRaycastTest {

  private val width = 1080f
  private val height = 1920f
  private val cx = width / 2f
  private val cy = height / 2f
  private val orbPx = EarthGeometry.orbScreenRadiusFractionOfHeight * height

  private fun centreHit(orientation: Mat4): LatLon? =
    EarthInteraction.raycastLatLon(cx, cy, width, height, orientation)

  private fun assertSamePlace(lat: Float, lon: Float, actual: LatLon?) {
    assertNotNull(actual, "expected a hit near ($lat, $lon)")
    // Compare on the sphere, so −180° and 180° are the same meridian.
    val gap = (sphereUnitVector(lat, lon) - sphereUnitVector(actual.lat, actual.lon)).length
    assertTrue(gap < 1e-3f, "($lat, $lon) came back as $actual (chord $gap)")
  }

  @Test
  fun viewCentreHitsNullIslandUnrotated() {
    val hit = assertNotNull(centreHit(Mat4.Identity))
    assertEquals(0f, hit.lat, 1e-4f)
    assertEquals(0f, hit.lon, 1e-4f)
  }

  /** The tilt alone spins the globe about the view axis, so the centre still hits (0, 0). */
  @Test
  fun viewCentreIsUnmovedByTheAxialTilt() {
    assertSamePlace(0f, 0f, centreHit(Mat4.rotationZ(EarthGeometry.AXIAL_TILT)))
  }

  @Test
  fun aPointAboveCentreIsNorth() {
    val hit = assertNotNull(EarthInteraction.raycastLatLon(cx, cy - 0.5f * orbPx, width, height, Mat4.Identity))
    assertTrue(hit.lat > 20f, "lat ${hit.lat}")
    assertEquals(0f, hit.lon, 1e-3f)
  }

  @Test
  fun pointsOffTheOrbMiss() {
    assertNull(EarthInteraction.raycastLatLon(cx, cy - 1.3f * orbPx, width, height, Mat4.Identity))
    assertNull(EarthInteraction.raycastLatLon(0f, 0f, width, height, Mat4.Identity))
    assertNull(EarthInteraction.raycastLatLon(cx, cy, 0f, height, Mat4.Identity))
  }

  /**
   * The orb's on-screen radius (fraction × height) is the limb: a hair inside it hits the
   * sphere right by the silhouette's tangent point — latitude acos(R / D) ≈ 83.2° seen from
   * the camera — and a hair outside it misses. Horizontally too: the radius is in pixels,
   * not a fraction of the width.
   */
  @Test
  fun theOrbsScreenRadiusIsTheLimb() {
    val limbLatDeg = acos(1f / EarthGeometry.CAMERA_DISTANCE) / DEG

    val top = assertNotNull(EarthInteraction.raycastLatLon(cx, cy - 0.999f * orbPx, width, height, Mat4.Identity))
    assertTrue(top.lat in (limbLatDeg - 5f)..limbLatDeg, "lat ${top.lat} vs limb $limbLatDeg")
    assertNull(EarthInteraction.raycastLatLon(cx, cy - 1.001f * orbPx, width, height, Mat4.Identity))

    val right = assertNotNull(EarthInteraction.raycastLatLon(cx + 0.999f * orbPx, cy, width, height, Mat4.Identity))
    assertTrue(right.lon in (limbLatDeg - 5f)..limbLatDeg, "lon ${right.lon} vs limb $limbLatDeg")
    assertNull(EarthInteraction.raycastLatLon(cx + 1.001f * orbPx, cy, width, height, Mat4.Identity))
  }

  @Test
  fun anInstantSettleCentresItsTargetUnderTheTilt() {
    val places = listOf(
      15.87f to 100.99f, // Thailand
      -33.9f to 151.2f, // Sydney
      51.5f to -0.1f, // London
      64f to -150f,
      -60f to -170f,
      0f to 180f,
      0f to 0f,
    )
    for ((lat, lon) in places) {
      val interaction = EarthInteraction()
      interaction.orientationMatrix(0.0)
      interaction.settle(lat, lon, overSeconds = 0.0)
      val orientation = interaction.orientationMatrix(1.0)

      // T·p = (0, 0, 1) with the tilt composed on top: the tilt leaves the front axis fixed.
      val front = orientation.transformDirection(sphereUnitVector(lat, lon))
      assertEquals(1f, front.z, 1e-5f, "($lat, $lon) faces $front")
      assertSamePlace(lat, lon, centreHit(interaction.currentOrientationMatrix()))
    }
  }

  /** Past the ±85° pitch limit the turn tops out; the centre lands on the clamped latitude. */
  @Test
  fun aPolarSettleStopsAtThePitchLimit() {
    val interaction = EarthInteraction()
    interaction.orientationMatrix(0.0)
    interaction.settle(89f, 10f, overSeconds = 0.0)
    interaction.orientationMatrix(0.5)
    assertSamePlace(85f, 10f, centreHit(interaction.currentOrientationMatrix()))
  }
}
