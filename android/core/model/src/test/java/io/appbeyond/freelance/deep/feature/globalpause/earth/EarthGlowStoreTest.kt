package io.appbeyond.freelance.deep.feature.globalpause.earth

import io.appbeyond.freelance.deep.feature.globalpause.earth.EarthGlowStore.GlowPointStyle
import io.appbeyond.freelance.deep.feature.globalpause.earth.EarthGlowStore.SparkStyle
import io.appbeyond.freelance.deep.feature.globalpause.earth.EarthGlowStore.Tuning
import io.appbeyond.freelance.deep.feature.globalpause.model.PauseJoinPoint
import io.appbeyond.freelance.deep.feature.globalpause.model.PauseLiveSnapshot.GeoPoint
import org.junit.jupiter.api.Test
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.ln
import kotlin.math.log2
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.random.Random
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/**
 * Ported behaviour from Deep/Deep/Features/GlobalPause/Earth3D/EarthGlowStore.swift and
 * EarthRendererTypes.swift (`GlowSourceGPU`'s range packing). iOS has no tests for these;
 * these are new, written from the iOS behaviour plus the documented Android riders
 * (`radiusPacked.w` carrying `cosReach`, the `lightVolumeReach` ray cull).
 *
 * What it guards: live presence lands on the GPU in the layout the shader loops — three
 * contiguous ranges, each channel meaning what its range says — a join's spark always
 * survives the 64-source budget, polls crossfade instead of popping, and the cull values
 * never reject a pixel the full maths would have lit.
 */
class EarthGlowStoreTest {

  /** One packed source: positionAndIntensity then radiusPacked. */
  private class Src(f: FloatArray) {
    val position = Vec3(f[0], f[1], f[2])
    val intensity = f[3]
    val radius = f[4]
    val whiteness = f[5]
    val z = f[6]
    val w = f[7]
  }

  private fun EarthGlowSnapshot.sources(): List<Src> =
    List(count) { i -> Src(data.copyOfRange(i * 8, i * 8 + 8)) }

  private fun EarthGlowSnapshot.classic() = sources().subList(0, classicCount)
  private fun EarthGlowSnapshot.orbs() = sources().subList(classicCount, classicCount + orbCount)
  private fun EarthGlowSnapshot.shells() = sources().subList(classicCount + orbCount, count)

  /** Ticks in 0.05 s steps (the store's dt clamp) — returns the last time. */
  private fun EarthGlowStore.ticks(from: Double, steps: Int): Double {
    tick(from)
    for (i in 1..steps) tick(from + i * 0.05)
    return from + steps * 0.05
  }

  private fun assertVec(expected: Vec3, actual: Vec3, tolerance: Float = 1e-5f) {
    assertEquals(expected.x, actual.x, tolerance, "x of $actual")
    assertEquals(expected.y, actual.y, tolerance, "y of $actual")
    assertEquals(expected.z, actual.z, tolerance, "z of $actual")
  }

  private fun pointTarget(count: Int, tuning: Tuning = Tuning()): Float =
    tuning.pointBaseIntensity + tuning.pointIntensityGain * min(1f, log2(count + 1f) / log2(tuning.pointSoftCap + 1f))

  private fun pointRadius(count: Int, tuning: Tuning = Tuning()): Float =
    tuning.pointBaseRadius + tuning.pointRadiusGain * min(1f, log2(count + 1f) / log2(tuning.pointSoftCap + 1f))

  // MARK: - Steady cells

  @Test
  fun defaultStyleIsBuriedSoSteadyCellsPackAsOrbsInModeTwo() {
    assertEquals(GlowPointStyle.Buried, Tuning().glowPointStyle)
    val store = EarthGlowStore()
    store.locations = listOf(GeoPoint(13.75f, 100.5f, 1))
    store.settleAtTargets()
    val snap = store.currentGpuSnapshot()
    assertEquals(1, snap.count)
    assertEquals(0, snap.classicCount)
    assertEquals(1, snap.orbCount)
    val orb = snap.orbs().single()
    assertEquals(2f, orb.z)
    assertEquals(0f, orb.whiteness)
    assertEquals(pointRadius(1), orb.radius, 1e-6f)
    assertEquals(pointTarget(1), orb.intensity, 1e-6f)
    assertVec(sphereUnitVector(13.75f, 100.5f), orb.position)
    assertEquals(EarthGlowStore.cosReach(orb.radius), orb.w)
  }

  @Test
  fun orbRadiiAreClampedBetween18And55Thousandths() {
    val wide = EarthGlowStore()
    wide.unlocatedByCountry = mapOf("RU" to 4) // 0.22 rad blob
    wide.settleAtTargets()
    assertEquals(0.055f, wide.currentGpuSnapshot().orbs().single().radius)

    val tiny = EarthGlowStore(Tuning(pointBaseRadius = 0.005f, pointRadiusGain = 0f))
    tiny.locations = listOf(GeoPoint(0f, 0f, 1))
    tiny.settleAtTargets()
    assertEquals(0.018f, tiny.currentGpuSnapshot().orbs().single().radius)
  }

  @Test
  fun classicStyleKeepsTheAngularRadiusAndAColumnOfOne() {
    val store = EarthGlowStore(Tuning(glowPointStyle = GlowPointStyle.Classic))
    store.unlocatedByCountry = mapOf("RU" to 4)
    store.settleAtTargets()
    val snap = store.currentGpuSnapshot()
    assertEquals(1, snap.classicCount)
    assertEquals(0, snap.orbCount)
    val blob = snap.classic().single()
    assertEquals(0.22f, blob.radius)
    assertEquals(1f, blob.z)
  }

  @Test
  fun dormantCellsAreNotUploaded() {
    val store = EarthGlowStore()
    store.locations = listOf(GeoPoint(13.75f, 100.5f, 1))
    // Targets set, nothing lerped yet: current 0 is under the 0.003 floor.
    assertEquals(0, store.currentGpuSnapshot().count)
    assertEquals(0, store.activeSourceCount)
  }

  @Test
  fun lerpApproachesTheTargetWithTauPointEightAndClampsDt() {
    val store = EarthGlowStore()
    store.locations = listOf(GeoPoint(13.75f, 100.5f, 1))
    val target = pointTarget(1)

    store.tick(10.0)
    store.tick(10.03)
    val k1 = 1f - exp(-0.03f / 0.8f)
    val first = target * k1
    assertEquals(first, store.currentGpuSnapshot().orbs().single().intensity, 1e-6f)

    // A 5 s stall advances only one clamped 0.05 s step.
    store.tick(15.03)
    val k2 = 1f - exp(-0.05f / 0.8f)
    assertEquals(first + (target - first) * k2, store.currentGpuSnapshot().orbs().single().intensity, 1e-6f)

    // Time going backwards is ignored.
    store.tick(14.0)
    assertEquals(first + (target - first) * k2, store.currentGpuSnapshot().orbs().single().intensity, 1e-6f)
  }

  @Test
  fun cellKeyQuantisesToAQuarterDegreeRoundingHalfAwayFromZero() {
    assertEquals("pt:1|-1", EarthGlowStore.cellKey(0.125f, -0.125f))
    assertEquals("pt:0|0", EarthGlowStore.cellKey(0.1f, -0.1f))
    assertEquals("pt:2|-2", EarthGlowStore.cellKey(0.375f, -0.375f))
    assertEquals("pt:55|402", EarthGlowStore.cellKey(13.75f, 100.5f))
  }

  @Test
  fun twoServerPointsInOneCellMergeAtTheCountWeightedMean() {
    val store = EarthGlowStore()
    store.locations = listOf(
      GeoPoint(10.0f, 20.0f, 1),
      GeoPoint(10.1f, 20.1f, 3),
      GeoPoint(40f, 40f, 0), // nobody there: skipped
    )
    store.settleAtTargets()
    val merged = store.currentGpuSnapshot().orbs().single()
    assertVec(sphereUnitVector(10.075f, 20.075f), merged.position)
    assertEquals(pointTarget(4), merged.intensity, 1e-6f)
    assertEquals(pointRadius(4), merged.radius, 1e-6f)
  }

  @Test
  fun unlocatedCountriesRenderBlobsAndTinyOnesSplashIntoTheirContinent() {
    val store = EarthGlowStore(Tuning(glowPointStyle = GlowPointStyle.Classic))
    store.unlocatedByCountry = mapOf("TH" to 5, "SG" to 2)
    store.settleAtTargets()
    val sources = store.currentGpuSnapshot().sources()
    assertEquals(3, sources.size)

    val logMax = ln(6f)
    val sgX = ln(3f) / logMax
    val sg = sgX * sgX * (3f - 2f * sgX)

    fun at(v: Vec3) = assertNotNull(sources.firstOrNull { (it.position - v).length < 1e-5f })
    val th = at(CountryLookup.country("TH")!!.unitVector)
    assertEquals(1f, th.intensity, 1e-6f)
    assertEquals(0.055f, th.radius)
    val singapore = at(CountryLookup.country("SG")!!.unitVector)
    assertEquals(sg, singapore.intensity, 1e-6f)
    assertEquals(0.022f, singapore.radius)
    val asia = at(CountryLookup.continentCenter("AS")!!.unitVector)
    assertEquals(0.35f * sg, asia.intensity, 1e-6f)
    assertEquals(0.30f, asia.radius)
  }

  @Test
  fun unlocatedBlobsSitAlongsideLocatedPoints() {
    val store = EarthGlowStore()
    store.locations = listOf(GeoPoint(51.5f, -0.1f, 2))
    store.unlocatedByCountry = mapOf("JP" to 1)
    store.settleAtTargets()
    assertEquals(2, store.currentGpuSnapshot().count)
  }

  @Test
  fun participantsByCountryIsUsedOnlyWhenLocationsAndUnlocatedAreBothEmpty() {
    val store = EarthGlowStore()
    val japan = CountryLookup.country("JP")!!.unitVector
    store.locations = listOf(GeoPoint(13.75f, 100.5f, 1))
    store.participantsByCountry = mapOf("JP" to 3)
    store.settleAtTargets()
    val withLocations = store.currentGpuSnapshot().sources()
    assertEquals(1, withLocations.size)
    assertVec(sphereUnitVector(13.75f, 100.5f), withLocations.single().position)

    store.locations = emptyList()
    store.settleAtTargets() // the vanished point fades to 0 and drops out
    val legacy = store.currentGpuSnapshot().sources()
    assertEquals(1, legacy.size)
    assertVec(japan, legacy.single().position)

    store.unlocatedByCountry = mapOf("TH" to 1)
    store.settleAtTargets()
    val unlocated = store.currentGpuSnapshot().sources()
    assertEquals(1, unlocated.size)
    assertVec(CountryLookup.country("TH")!!.unitVector, unlocated.single().position)
  }

  @Test
  fun aVanishedSourceFadesInsteadOfPopping() {
    val store = EarthGlowStore()
    store.locations = listOf(GeoPoint(13.75f, 100.5f, 1))
    store.settleAtTargets()
    store.locations = emptyList()
    store.ticks(0.0, 1)
    val fading = store.currentGpuSnapshot().orbs().single()
    assertEquals(pointTarget(1) * exp(-0.05f / 0.8f), fading.intensity, 1e-6f)
  }

  @Test
  fun homeGlowIsCreamTintedAndBreathesThirteenPercent() {
    val store = EarthGlowStore()
    store.homeLocation = PauseJoinPoint(13.8f, 100.5f)
    store.settleAtTargets()

    store.tick((PI / 2) / 0.63)
    val inhaled = store.currentGpuSnapshot().orbs().single()
    assertEquals(0.15f, inhaled.whiteness)
    assertEquals(0.045f, inhaled.radius)
    assertEquals(2f, inhaled.z)
    assertEquals(0.9f * 1.13f, inhaled.intensity, 1e-4f)

    store.tick((3 * PI / 2) / 0.63)
    assertEquals(0.9f * 0.87f, store.currentGpuSnapshot().orbs().single().intensity, 1e-4f)
  }

  @Test
  fun homeColumnIsTallerInClassicStyle() {
    val store = EarthGlowStore(Tuning(glowPointStyle = GlowPointStyle.Classic))
    store.homeLocation = PauseJoinPoint(13.8f, 100.5f)
    store.settleAtTargets()
    assertEquals(1.35f, store.currentGpuSnapshot().classic().single().z)
  }

  // MARK: - Sparks

  @Test
  fun aClassicSparkPacksTheSeatInTheClassicRange() {
    val store = EarthGlowStore(random = Random(7))
    store.locations = listOf(GeoPoint(51.5f, -0.1f, 2))
    store.settleAtTargets()
    store.spark(13.75f, 100.5f)
    store.ticks(0.0, 5) // age 0.25

    val snap = store.currentGpuSnapshot()
    assertEquals(1, snap.classicCount)
    assertEquals(1, snap.orbCount)
    val seat = snap.classic().single()
    val age = 0.25f
    assertVec(sphereUnitVector(13.75f, 100.5f), seat.position)
    assertEquals(0.030f, seat.radius)
    assertEquals(1.3f * exp(-(age - 0.12f) / 0.6f), seat.intensity, 1e-4f)
    assertEquals(exp(-age / 0.45f), seat.whiteness, 1e-4f)
    assertTrue(seat.whiteness > 0f)
    assertEquals(1f + 1.5f * exp(-age / 0.45f), seat.z, 1e-4f)
    assertEquals(EarthGlowStore.cosReach(0.030f), seat.w)
  }

  @Test
  fun aSparkAtBirthIsDarkUntilItsAttack() {
    val store = EarthGlowStore(random = Random(1))
    store.spark(0f, 0f)
    assertEquals(0, store.currentGpuSnapshot().count)
    assertEquals(1, store.sparkCount)
  }

  @Test
  fun flashShellSparkPacksSeatFlashAndShellInContiguousRanges() {
    val tuning = Tuning(sparkStyle = SparkStyle.FlashShell)
    val store = EarthGlowStore(tuning, Random(3))
    store.locations = listOf(GeoPoint(51.5f, -0.1f, 2))
    store.settleAtTargets()
    store.spark(13.75f, 100.5f)

    // At 0.05 s the shell is still inside 4× its thickness: no shell yet.
    store.ticks(0.0, 1)
    val early = store.currentGpuSnapshot()
    assertEquals(early.classicCount + early.orbCount, early.count)

    store.ticks(0.05, 5) // age 0.3
    val age = 0.3f
    val snap = store.currentGpuSnapshot()
    assertEquals(1, snap.classicCount)
    assertEquals(2, snap.orbCount)
    assertEquals(4, snap.count)

    val seat = snap.classic().single()
    assertEquals(EarthGlowStore.cosReach(seat.radius), seat.w)

    val (steady, flash) = snap.orbs()
    assertEquals(2f, steady.z)
    assertEquals(0f, flash.z)
    assertEquals(0.05f, flash.radius)
    assertEquals(1.8f * exp(-age / 0.12f), flash.intensity, 1e-4f)
    assertEquals(exp(-age / 0.35f), flash.whiteness, 1e-4f)
    for (orb in snap.orbs()) assertEquals(EarthGlowStore.cosReach(orb.radius), orb.w)

    val shell = snap.shells().single()
    val u = age / 1.4f
    val radius = 0.42f * (1f - (1f - u).pow(3))
    assertEquals(radius, shell.radius, 1e-4f)
    assertEquals(0.010f + 0.045f * shell.radius, shell.z, 1e-6f)
    assertTrue(shell.radius > 4f * shell.z)
    assertEquals((1f - u).pow(1.5f) * 1.15f, shell.intensity, 1e-4f)
    assertEquals(exp(-age / 0.35f), shell.whiteness, 1e-4f)
    assertEquals(0f, shell.w)
    assertVec(sphereUnitVector(13.75f, 100.5f), shell.position)
  }

  @Test
  fun sparksAlwaysSurviveTheBudgetAndTheDimmestGoingSteadyCellsDrop() {
    val store = EarthGlowStore(random = Random(11))
    // 60 cells of 6 (target 0.95) and 10 of 1 (target ≈ 0.757): 70 > 64.
    store.locations = List(70) { i ->
      GeoPoint(-60f + i * 1.7f, -170f + i * 4.9f, if (i % 7 == 3) 1 else 6)
    }
    assertEquals(10, store.locations.count { it.count == 1 })
    store.settleAtTargets()
    repeat(4) { store.spark(-10f + it * 9f, 20f + it * 11f) }
    store.ticks(0.0, 2)

    val snap = store.currentGpuSnapshot()
    assertEquals(64, snap.count)
    assertEquals(4, snap.classicCount)
    assertEquals(60, snap.orbCount)
    for (orb in snap.orbs()) assertEquals(pointTarget(6), orb.intensity, 1e-6f)
  }

  @Test
  fun aFreshCellOutranksAFadingOne() {
    val store = EarthGlowStore()
    store.locations = List(64) { i -> GeoPoint(-60f + i * 1.8f, -170f + i * 5f, 6) }
    store.settleAtTargets()
    // A whole new world: 64 fresh cells (current 0) while the old 64 fade (target 0).
    store.locations = List(64) { i -> GeoPoint(-59f + i * 1.8f, -169f + i * 5f, 6) }
    store.ticks(0.0, 1)

    val snap = store.currentGpuSnapshot()
    assertEquals(64, snap.count)
    val fresh = pointTarget(6) * (1f - exp(-0.05f / 0.8f))
    for (orb in snap.orbs()) assertEquals(fresh, orb.intensity, 1e-5f)
  }

  @Test
  fun sparksExpireAfterTheirLife() {
    val store = EarthGlowStore(random = Random(5))
    store.spark(0f, 0f)
    val t = store.ticks(0.0, 38) // 1.9 s
    assertEquals(1, store.sparkCount)
    store.ticks(t, 4) // 2.1 s
    assertEquals(0, store.sparkCount)
  }

  @Test
  fun flashShellSparksLiveAsLongAsTheLongerEnvelope() {
    val store = EarthGlowStore(Tuning(sparkStyle = SparkStyle.FlashShell, sparkLife = 1f), Random(5))
    store.spark(0f, 0f)
    val t = store.ticks(0.0, 26) // 1.3 s: past sparkLife, inside shellLife 1.4
    assertEquals(1, store.sparkCount)
    store.ticks(t, 3) // 1.45 s
    assertEquals(0, store.sparkCount)
  }

  @Test
  fun theSparkCapEvictsTheOldest() {
    val store = EarthGlowStore(random = Random(9))
    for (i in 0 until 9) store.spark(0f, i * 10f)
    assertEquals(8, store.sparkCount)
    store.ticks(0.0, 1)
    val seats = store.currentGpuSnapshot().classic()
    assertEquals(8, seats.size)
    assertTrue(seats.none { (it.position - sphereUnitVector(0f, 0f)).length < 1e-5f })
    assertTrue(seats.any { (it.position - sphereUnitVector(0f, 80f)).length < 1e-5f })
  }

  @Test
  fun clearSparksDropsEverySparkInFlight() {
    val store = EarthGlowStore(random = Random(2))
    repeat(3) { store.spark(10f, it * 20f) }
    store.clearSparks()
    assertEquals(0, store.sparkCount)
  }

  // MARK: - Cull values (Android Fix A / Fix B)

  @Test
  fun cosReachIsTheCosineOfSevenAndAHalfRadiiPlusAMarginOrMinusOnePastTheAntipode() {
    val m = EarthGlowStore.COS_REACH_MARGIN
    assertEquals(cos(7.5f * 0.05f + m), EarthGlowStore.cosReach(0.05f))
    assertEquals(cos(7.5f * 0.4f + m), EarthGlowStore.cosReach(0.4f))
    // Floored at 0.01.
    assertEquals(cos(7.5f * 0.01f + m), EarthGlowStore.cosReach(0.001f))
    assertEquals(cos(7.5f * 0.01f + m), EarthGlowStore.cosReach(0f))
    // 7.5 · 0.42 > π: nothing on the sphere is out of reach.
    assertEquals(-1f, EarthGlowStore.cosReach(0.42f))
    assertEquals(-1f, EarthGlowStore.cosReach(2f))
  }

  /** The pre-reject must never be stricter than the shader's `x > 7.5`. */
  @Test
  fun cosReachNeverRejectsWhatTheAngleTestKeeps() {
    for (r in listOf(0.01f, 0.03f, 0.055f, 0.1f, 0.3f, 0.41f)) {
      val boundary = 7.5f * r
      val keptCos = cos(boundary * 0.99999f)
      kotlin.test.assertTrue(keptCos >= EarthGlowStore.cosReach(r), "radius $r")
    }
  }

  @Test
  fun lightVolumeReachIsZeroWithNoOrbsOrShells() {
    assertEquals(0f, EarthGlowSnapshot.Empty.lightVolumeReach(1f, 0.01f))
    assertEquals(0f, EarthGlowStore().currentGpuSnapshot().lightVolumeReach(1f, 0.01f))

    val classic = EarthGlowStore(Tuning(glowPointStyle = GlowPointStyle.Classic))
    classic.locations = listOf(GeoPoint(0f, 0f, 3))
    classic.settleAtTargets()
    val snap = classic.currentGpuSnapshot()
    assertEquals(1, snap.count)
    assertEquals(0f, snap.lightVolumeReach(1f, 0.01f))
  }

  @Test
  fun lightVolumeReachCoversTheWidestOrb() {
    val store = EarthGlowStore()
    store.locations = listOf(GeoPoint(0f, 0f, 1), GeoPoint(30f, 30f, 6))
    store.settleAtTargets()
    val snap = store.currentGpuSnapshot()
    val sigma = max(pointRadius(1), pointRadius(6))
    assertEquals(1.05f + 7.5f * sigma, snap.lightVolumeReach(1f, 0.01f), 1e-6f)
    assertEquals(1.1f * 1.05f + 7.5f * 2f * sigma, snap.lightVolumeReach(2f, 0.01f, radiusScale = 1.1f), 1e-6f)
  }

  @Test
  fun lightVolumeReachCoversTheShellWithItsPixelFloor() {
    val store = EarthGlowStore(Tuning(sparkStyle = SparkStyle.FlashShell), Random(4))
    store.spark(20f, 20f)
    store.ticks(0.0, 16) // 0.8 s: the flash has died, the shell is still out
    val snap = store.currentGpuSnapshot()
    assertEquals(0, snap.orbCount)
    val shell = snap.shells().single()
    assertEquals(1f + shell.radius + 3f * shell.z, snap.lightVolumeReach(1f, 0.001f), 1e-6f)
    assertEquals(1f + shell.radius + 3f * 0.15f, snap.lightVolumeReach(1f, 0.1f), 1e-6f)
  }
}
