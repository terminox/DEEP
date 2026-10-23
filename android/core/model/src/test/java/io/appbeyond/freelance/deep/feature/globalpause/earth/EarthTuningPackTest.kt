package io.appbeyond.freelance.deep.feature.globalpause.earth

import org.junit.jupiter.api.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

/**
 * Ported behaviour from Deep/Deep/Features/GlobalPause/Earth3D/EarthTuning.swift
 * (`EarthTuning.Values` and its `gpu` packing) and Shaders/EarthTuningShared.h. iOS has no
 * tests for these; these are new, written from the iOS behaviour.
 *
 * What it guards: the 18-`vec4` tuning block the shader reads by slot. One field packed a
 * slot early or late renders a different Earth with no error anywhere, so the whole layout
 * is pinned here against the iOS defaults, plus the two Android riders in slots iOS leaves
 * unused (`glass.y` × render scale, `orbSeat.y` = light-volume reach).
 */
class EarthTuningPackTest {

  /** `EarthTuning.Values().gpu` on iOS, slot by slot, in `EarthTuningShared.h` order. */
  private val iosShipped = floatArrayOf(
    0.30f, 1.2f, 0.75f, 0.35f, // glowShape
    0.1f, 2.0f, 0f, 0.06f, // haze
    0.32f, 0.68f, 0.40f, 0.75f, // continentBand
    0.15f, 0.55f, 0.30f, 0.70f, // coastBand
    0.18f, 0.06f, 0.25f, 0.75f, // iridescence
    2.2f, 1.0f, 1.45f, 0.45f, // glass
    0.55f, 0.45f, 0.42f, 0.45f, // backBleed
    1.00f, 0.30f, 0.40f, 0.40f, // emissiveA
    1.50f, 0.90f, 0.08f, 1.0f, // emissiveB
    0.92f, 0.18f, 1.20f, 0.30f, // alphaA
    0.42f, 0.88f, 3.0f, 0.45f, // bloomA
    1.5f, 0.6f, 0f, 0f, // bloomB
    0f, 0.75f, 0.85f, 0.35f, // lit
    0.8f, 0.6f, 0.6f, 0.25f, // volumetric
    1.0f, 2.6f, 0.9f, 1.4f, // orbShape
    0.45f, 0.85f, 0.35f, 1.6f, // orbTint
    1.6f, 0.85f, 0.8f, 0.6f, // burstShape
    0.35f, 0f, 0f, 0f, // orbSeat
  )

  @Test
  fun packsExactlySeventyTwoFloats() {
    assertEquals(72, EarthTuning.FLOATS)
    assertEquals(288, EarthTuning.BYTES)
    assertEquals(72, iosShipped.size)
    val out = FloatArray(80) { -7f }
    EarthTuning().pack(out)
    for (i in 72 until 80) assertEquals(-7f, out[i], "slot $i was written")
  }

  @Test
  fun shippedDefaultsPackAsIosDoes() {
    val out = FloatArray(72)
    EarthTuning.Shipped.pack(out)
    for (i in 0 until 72) assertEquals(iosShipped[i], out[i], "float $i (vec4 ${i / 4}.${"xyzw"[i % 4]})")
  }

  @Test
  fun spotChecksAgainstTheSharedHeader() {
    val out = FloatArray(72)
    EarthTuning().pack(out, rimScale = 2.5f, lightVolumeReach = 1.4f)
    assertEquals(0.30f, out[0]) // glowShape.x = haloWeight
    assertEquals(2.2f, out[20]) // glass.x = fresnelBodyExp
    assertEquals(2.5f, out[21]) // glass.y = rimTightness × rimScale
    assertEquals(1.45f, out[22]) // glass.z = refractiveIndex
    assertEquals(0.45f, out[23]) // glass.w = rimColorMix
    assertEquals(1.5f, out[44]) // bloomB.x = tonemapK
    assertEquals(1.0f, out[56]) // orbShape.x = sigmaScale
    assertEquals(0.35f, out[68]) // orbSeat.x = seatWeight
    assertEquals(1.4f, out[69]) // orbSeat.y = light-volume reach (Android)
    assertEquals(0f, out[70])
    assertEquals(0f, out[71])
  }

  @Test
  fun rimScaleMultipliesTheTunedTightness() {
    val out = FloatArray(72)
    EarthTuning(rimTightness = 1.3f).pack(out, rimScale = 2f)
    assertEquals(2.6f, out[21], 1e-6f)
  }

  @Test
  fun aShortBufferIsRefused() {
    assertFailsWith<IllegalArgumentException> { EarthTuning().pack(FloatArray(71)) }
  }

  @Test
  fun defaultsMatchIosValues() {
    val t = EarthTuning()
    assertEquals(1.2f, t.glowExposure)
    assertEquals(0.06f, t.shimmerAmp)
    assertEquals(0.40f, t.inlandLo)
    assertEquals(0.42f, t.backBleedTint)
    assertEquals(1.50f, t.emissiveRim)
    assertEquals(0.92f, t.alphaContinent)
    assertEquals(0.88f, t.bloomThresholdHi)
    assertEquals(0.85f, t.volIntensity)
    assertEquals(2.6f, t.orbExposure)
    assertEquals(1.6f, t.orbElevRatio)
    assertEquals(0.8f, t.burstHotGain)
    // CPU-side
    assertEquals(-0.45f, t.sunX)
    assertEquals(0.55f, t.sunY)
    assertEquals(0.7f, t.sunZ)
    assertEquals(0.1f, t.atmosphereStrength)
    assertEquals(4.0f, t.breathInhaleSeconds)
    assertEquals(6.0f, t.breathExhaleSeconds)
  }
}
