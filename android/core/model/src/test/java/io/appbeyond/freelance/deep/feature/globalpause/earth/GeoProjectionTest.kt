package io.appbeyond.freelance.deep.feature.globalpause.earth

import io.appbeyond.freelance.deep.feature.globalpause.model.PauseJoinPoint
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Ported behaviour from Deep/Deep/Features/GlobalPause/Earth3D/Geo/GeoMath.swift and
 * Geo/CountryLookup.swift. iOS has no tests for these; these are new, written from the
 * iOS behaviour.
 *
 * What it guards: the one lat/lon → sphere convention every globe layer shares (glow
 * store, ripples, tap raycast), and the country table the tap resolves through. If the
 * convention drifts, a glow lands on the wrong country and a tap on Thailand names
 * somewhere else.
 */
class GeoProjectionTest {

  private fun assertVec(expected: Vec3, actual: Vec3, tolerance: Float = 1e-5f) {
    assertEquals(expected.x, actual.x, tolerance, "x of $actual")
    assertEquals(expected.y, actual.y, tolerance, "y of $actual")
    assertEquals(expected.z, actual.z, tolerance, "z of $actual")
  }

  @Test
  fun nullIslandFacesTheCameraOnPlusZ() {
    assertVec(Vec3(0f, 0f, 1f), sphereUnitVector(0f, 0f))
  }

  @Test
  fun ninetyEastIsPlusX() {
    assertVec(Vec3(1f, 0f, 0f), sphereUnitVector(0f, 90f))
    assertVec(Vec3(-1f, 0f, 0f), sphereUnitVector(0f, -90f))
  }

  @Test
  fun thePolesArePlusAndMinusYAtAnyLongitude() {
    for (lon in listOf(-180f, -73f, 0f, 45f, 179.9f)) {
      assertVec(Vec3(0f, 1f, 0f), sphereUnitVector(90f, lon))
      assertVec(Vec3(0f, -1f, 0f), sphereUnitVector(-90f, lon))
    }
  }

  @Test
  fun everyPointIsUnitLength() {
    for (lat in -90..90 step 15) {
      for (lon in -180..180 step 30) {
        assertEquals(1f, sphereUnitVector(lat.toFloat(), lon.toFloat()).length, 1e-6f)
      }
    }
  }

  @Test
  fun latLonOfRoundTrips() {
    for (lat in -85..85 step 17) {
      for (lon in -175..175 step 35) {
        val back = latLonOf(sphereUnitVector(lat.toFloat(), lon.toFloat()))
        assertEquals(lat.toFloat(), back.lat, 1e-3f)
        assertEquals(lon.toFloat(), back.lon, 1e-3f)
      }
    }
  }

  /** A float a hair past unit length must not NaN the latitude. */
  @Test
  fun latLonOfClampsAnOverlongY() {
    val pole = latLonOf(Vec3(0f, 1.0000001f, 0f))
    assertEquals(90f, pole.lat, 1e-4f)
  }

  @Test
  fun bangkokResolvesToThailand() {
    assertEquals("TH", CountryLookup.nearestCountry(13.75f, 100.5f, withinDegrees = 6f)?.iso2)
  }

  /** The tap's 6° tolerance: open ocean names nobody. */
  @Test
  fun midPacificResolvesToNobodyWithinSixDegrees() {
    assertNull(CountryLookup.nearestCountry(0f, -150f, withinDegrees = 6f))
    // There is still a nearest country — it is just too far away.
    assertNotNull(CountryLookup.nearestCountry(0f, -150f, withinDegrees = 180f))
  }

  /** 3° due north of Thailand's centroid, with every other country further off. */
  @Test
  fun withinDegreesIsTheCutoff() {
    val lat = 15.87f + 3f
    val lon = 100.99f
    assertEquals("TH", CountryLookup.nearestCountry(lat, lon, withinDegrees = 3.05f)?.iso2)
    assertNull(CountryLookup.nearestCountry(lat, lon, withinDegrees = 2.95f))
  }

  @Test
  fun centroidIsCaseInsensitive() {
    assertEquals(PauseJoinPoint(15.87f, 100.99f), CountryLookup.centroid("th"))
    assertEquals(CountryLookup.centroid("TH"), CountryLookup.centroid("th"))
    assertEquals("JP", CountryLookup.country("jp")?.iso2)
    assertNull(CountryLookup.centroid("zz"))
  }

  @Test
  fun countryUnitVectorsUseTheSharedProjection() {
    for (c in CountryLookup.countries) {
      assertVec(sphereUnitVector(c.latitude, c.longitude), c.unitVector, 0f)
    }
  }

  @Test
  fun continentCenterMatchesTheIosTable() {
    val asia = assertNotNull(CountryLookup.continentCenter("as"))
    assertEquals("AS", asia.iso)
    assertVec(sphereUnitVector(45f, 90f), asia.unitVector)
    assertEquals(0.30f, asia.angularRadius)

    val southAmerica = assertNotNull(CountryLookup.continentCenter("SA"))
    assertVec(sphereUnitVector(-15f, -60f), southAmerica.unitVector)
    assertEquals(0.22f, southAmerica.angularRadius)

    assertNull(CountryLookup.continentCenter("XX"))
  }

  /** A tiny country splashes into its continent, so every continent must resolve. */
  @Test
  fun everyCountrysContinentHasACenter() {
    for (c in CountryLookup.countries) {
      assertNotNull(CountryLookup.continentCenter(c.continentIso), "${c.iso2} → ${c.continentIso}")
    }
    assertEquals(CountryLookup.countries.size, CountryLookup.countries.map { it.iso2 }.toSet().size)
    assertTrue(CountryLookup.countries.any { it.isTiny })
  }
}
