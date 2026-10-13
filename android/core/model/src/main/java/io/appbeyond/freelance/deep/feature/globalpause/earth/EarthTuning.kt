package io.appbeyond.freelance.deep.feature.globalpause.earth

/**
 * Every look parameter of the Earth orb, at its shipped default — iOS's
 * `EarthTuning.Values`, value for value. Untouched, it renders the iOS look;
 * iOS's DEBUG dial panel (the only writer there) is not ported.
 *
 * [pack] lays the GPU-facing fields out as the 18 `vec4` slots of the
 * `EarthTuning` std140 uniform block (`earth_common.glsl`): 72 floats,
 * 288 bytes. The slot order and component meanings are the Metal
 * `EarthTuningUniforms` struct's, so a field here maps to a shader read
 * exactly as it does on iOS.
 */
data class EarthTuning(
  // Glow shape
  val glowHaloWeight: Float = 0.30f,
  val glowExposure: Float = 1.2f,
  val glowLandMix: Float = 0.75f,
  val glowBrightness: Float = 0.35f,
  val sparkFlash: Float = 0f,
  val coastGlow: Float = 0f,
  val litEmissive: Float = 0f,
  val litColorMix: Float = 0.75f,

  // Atmosphere & shimmer
  val hazeAlpha: Float = 0.1f,
  val hazeExponent: Float = 2.0f,
  val breathScaleAmp: Float = 0f,
  val shimmerAmp: Float = 0.06f,

  // Continent bands
  val continentLo: Float = 0.32f,
  val continentHi: Float = 0.68f,
  val inlandLo: Float = 0.40f,
  val inlandHi: Float = 0.75f,
  val coastLo: Float = 0.15f,
  val coastHi: Float = 0.55f,
  val backLo: Float = 0.30f,
  val backHi: Float = 0.70f,

  // Iridescence
  val iridescenceDriftSpeed: Float = 0.18f,
  val iridescenceDriftAmp: Float = 0.06f,
  val paletteStart: Float = 0.25f,
  val paletteSpan: Float = 0.75f,

  // Glass
  val fresnelBodyExponent: Float = 2.2f,
  val rimTightness: Float = 1.0f,
  val refractiveIndex: Float = 1.45f,
  val rimColorMix: Float = 0.45f,

  // Back-side bleed
  val backBleedBase: Float = 0.55f,
  val backBleedRimFade: Float = 0.45f,
  val backBleedTint: Float = 0.42f,
  val backBleedAlpha: Float = 0.45f,

  // Emissive weights
  val emissiveContinent: Float = 1.00f,
  val emissiveInland: Float = 0.30f,
  val emissiveSeaGlow: Float = 0.40f,
  val emissiveBackGlow: Float = 0.40f,
  val emissiveRim: Float = 1.50f,
  val emissiveEdge: Float = 0.90f,
  val emissiveBody: Float = 0.08f,
  val emissiveShimmer: Float = 1.0f,

  // Alpha weights
  val alphaContinent: Float = 0.92f,
  val alphaCoast: Float = 0.18f,
  val alphaRim: Float = 1.20f,
  val alphaSea: Float = 0.30f,

  // Bloom & composite
  val bloomThresholdLo: Float = 0.42f,
  val bloomThresholdHi: Float = 0.88f,
  val blurStepScale: Float = 3.0f,
  val bloomStrength: Float = 0.45f,
  val tonemapK: Float = 1.5f,
  val bloomAlphaLift: Float = 0.6f,

  // Volumetric glow
  val volIntensity: Float = 0.85f,
  val volHeight: Float = 0.35f,
  val volSoftness: Float = 0.8f,
  val volAlphaLift: Float = 0.6f,
  val volTintMix: Float = 0.6f,
  val volBackGhost: Float = 0.25f,

  // Glow orbs (3D style)
  val orbSigmaScale: Float = 1.0f,
  val orbExposure: Float = 2.6f,
  val orbGain: Float = 0.9f,
  val orbHotGain: Float = 1.4f,
  val orbCoreWhiteBoost: Float = 0.45f,
  val orbAlphaLift: Float = 0.85f,
  val orbHaloWeight: Float = 0.35f,
  val orbElevRatio: Float = 1.6f,
  val orbSeatWeight: Float = 0.35f,

  // Spark burst (3D style)
  val burstExposure: Float = 1.6f,
  val burstGain: Float = 0.85f,
  val burstHotGain: Float = 0.8f,
  val burstAlphaLift: Float = 0.6f,

  // CPU-side (EarthUniforms, not the tuning block)
  val sunX: Float = -0.45f,
  val sunY: Float = 0.55f,
  val sunZ: Float = 0.7f,
  val atmosphereStrength: Float = 0.1f,
  val breathInhaleSeconds: Float = 4.0f,
  val breathExhaleSeconds: Float = 6.0f,
) {

  /**
   * The tuning block's 72 floats.
   *
   * Two Android-only riders, both in slots iOS documents as unused:
   * - `glass.y` (rim tightness) is multiplied by [rimScale], the render
   *   scale. The scene renders below native resolution (`EARTH3D_SPIKE.md`
   *   §4.5), and the rim's alpha band sits in the outer ~0.1% of the radius —
   *   under one rendered pixel, so it would step. Scaling the one exponent
   *   that drives the coupled 10:18:28 rim triple widens the band in step
   *   with the coarser pixels, so it stays a smooth line.
   * - `orbSeat.y` carries [lightVolumeReach], the furthest any orb or shell
   *   reaches from the globe's centre this frame — the shader's ray cull
   *   (spike Fix A). `orbSeat.zw` stay zero.
   */
  fun pack(into: FloatArray, rimScale: Float = 1f, lightVolumeReach: Float = 0f) {
    require(into.size >= FLOATS) { "The tuning block needs $FLOATS floats" }
    var i = 0
    fun put(x: Float, y: Float, z: Float, w: Float) {
      into[i++] = x; into[i++] = y; into[i++] = z; into[i++] = w
    }
    put(glowHaloWeight, glowExposure, glowLandMix, glowBrightness)
    put(hazeAlpha, hazeExponent, breathScaleAmp, shimmerAmp)
    put(continentLo, continentHi, inlandLo, inlandHi)
    put(coastLo, coastHi, backLo, backHi)
    put(iridescenceDriftSpeed, iridescenceDriftAmp, paletteStart, paletteSpan)
    put(fresnelBodyExponent, rimTightness * rimScale, refractiveIndex, rimColorMix)
    put(backBleedBase, backBleedRimFade, backBleedTint, backBleedAlpha)
    put(emissiveContinent, emissiveInland, emissiveSeaGlow, emissiveBackGlow)
    put(emissiveRim, emissiveEdge, emissiveBody, emissiveShimmer)
    put(alphaContinent, alphaCoast, alphaRim, alphaSea)
    put(bloomThresholdLo, bloomThresholdHi, blurStepScale, bloomStrength)
    put(tonemapK, bloomAlphaLift, sparkFlash, coastGlow)
    put(litEmissive, litColorMix, volIntensity, volHeight)
    put(volSoftness, volAlphaLift, volTintMix, volBackGhost)
    put(orbSigmaScale, orbExposure, orbGain, orbHotGain)
    put(orbCoreWhiteBoost, orbAlphaLift, orbHaloWeight, orbElevRatio)
    put(burstExposure, burstGain, burstHotGain, burstAlphaLift)
    put(orbSeatWeight, lightVolumeReach, 0f, 0f)
    check(i == FLOATS) { "EarthTuning layout drifted from the shader's 18 vec4 block" }
  }

  companion object {
    /** 18 `vec4` = 72 floats = 288 bytes, as iOS asserts in `buildBuffers`. */
    const val FLOATS = 72
    const val BYTES = FLOATS * 4
    val Shipped = EarthTuning()
  }
}
