import Foundation
import simd
import Observation

/// Live-tunable look parameters for the Earth orb — the single source of truth
/// for every value that used to be a hardcoded literal in EarthSurface.metal,
/// EarthBloom.metal, and `EarthRenderer.makeUniforms`.
///
/// `Values()` (all defaults) reproduces the shipped look exactly, so this class
/// is inert outside the DEBUG tuning panel — which is the only writer. Shared
/// singleton rather than injected: there are two independent renderer creation
/// sites (`EarthSceneView`, `Earth3DView`) plus previews, and one knob set
/// should drive them all.
///
/// Threading: `EarthRenderer.draw(in:)` reads `gpu` and the CPU-side values
/// directly. That is safe because `MTKViewDelegate` is `@MainActor`, the same
/// guarantee the renderer's existing `glowStore` / `interaction` reads rely on.
@MainActor
@Observable
final class EarthTuning {
  static let shared = EarthTuning()

  /// Every tunable value with its shipped default. Reset = `values = Values()`.
  /// Codable + Equatable so the DEBUG dial panel can snapshot and diff it.
  struct Values: Codable, Equatable {
    // MARK: Glow shape
    /// Halo skirt weight around each glow source (σ = 3r term).
    var glowHaloWeight: Float = 0.30
    /// Compression gain in `1 − exp(−total·k)` — higher saturates sooner.
    var glowExposure: Float = 1.2
    /// How far participant glow re-colors the land palette.
    var glowLandMix: Float = 0.75
    /// Land brightness gain under glow.
    var glowBrightness: Float = 0.35
    /// Spark whiteness → extra land brightness flash. Neutral at 0; carries
    /// the spark pop when the recolor path (glowLandMix) is zeroed for the
    /// emissive-boost look.
    var sparkFlash: Float = 0
    /// Coast-halo band brightening under glow — keeps island/coastal cities
    /// readable without the sea-glow blob. Neutral at 0.
    var coastGlow: Float = 0
    /// Independent lit-land emissive — additive, decoupled from
    /// `emissiveContinent`, so the unlit world can rest near-dark while lit
    /// regions burn bright. Neutral at 0.
    var litEmissive: Float = 0
    /// Lit-land color: 0 = the land's own palette, 1 = the warm glow walk
    /// (lilac → blush → peach → cream). Inert while litEmissive is 0.
    var litColorMix: Float = 0.75

    // MARK: Atmosphere & shimmer
    /// Haze alpha just outside the silhouette.
    var hazeAlpha: Float = 0.1
    /// Haze falloff exponent — higher hugs the rim tighter.
    var hazeExponent: Float = 2.0
    /// Whole-orb breath scale amplitude.
    var breathScaleAmp: Float = 0.015
    /// FBM breath shimmer amplitude.
    var shimmerAmp: Float = 0.06

    // MARK: Continent bands (smoothstep edges over landRaw)
    var continentLo: Float = 0.32
    var continentHi: Float = 0.68
    /// "Deep inland" mask — the raised-continent brightness boost.
    var inlandLo: Float = 0.40
    var inlandHi: Float = 0.75
    /// Wider coast band; its excess over the continent mask is the coast halo.
    var coastLo: Float = 0.15
    var coastHi: Float = 0.55
    /// Refracted back-hemisphere continent mask.
    var backLo: Float = 0.30
    var backHi: Float = 0.70

    // MARK: Iridescence
    var iridescenceDriftSpeed: Float = 0.18
    var iridescenceDriftAmp: Float = 0.06
    /// Palette walk start/span: latitude maps to start + latT · span.
    var paletteStart: Float = 0.25
    var paletteSpan: Float = 0.75

    // MARK: Glass
    var fresnelBodyExponent: Float = 2.2
    /// Scales the coupled rim/edge/alpha fresnel exponents (10:18:28)
    /// proportionally — higher = thinner rim. 1.0 = shipped look.
    var rimTightness: Float = 1.0
    var refractiveIndex: Float = 1.45
    /// MOON_CREAM → dispersion mix in the rim color.
    var rimColorMix: Float = 0.45

    // MARK: Back-side bleed
    var backBleedBase: Float = 0.55
    var backBleedRimFade: Float = 0.45
    /// Palette position of the back-bleed tint.
    var backBleedTint: Float = 0.42
    var backBleedAlpha: Float = 0.45

    // MARK: Emissive weights
    var emissiveContinent: Float = 1.00
    var emissiveInland: Float = 0.30
    var emissiveSeaGlow: Float = 0.40
    var emissiveBackGlow: Float = 0.40
    var emissiveRim: Float = 1.50
    var emissiveEdge: Float = 0.90
    var emissiveBody: Float = 0.08
    var emissiveShimmer: Float = 1.0

    // MARK: Alpha weights
    var alphaContinent: Float = 0.92
    var alphaCoast: Float = 0.18
    var alphaRim: Float = 1.20
    var alphaSea: Float = 0.30

    // MARK: Bloom & composite
    var bloomThresholdLo: Float = 0.42
    var bloomThresholdHi: Float = 0.88
    /// Gaussian blur step, in bloom-texture texels.
    var blurStepScale: Float = 3.0
    var bloomStrength: Float = 0.45
    /// Luminance-compression k in the palette-preserving tonemap.
    var tonemapK: Float = 1.5
    var bloomAlphaLift: Float = 0.6

    // MARK: Volumetric glow
    /// Master gain for the 3D glow shell. 0 restores the flat surface-only look.
    var volIntensity: Float = 0.85
    /// Exponential scale height of a glow column, as a fraction of the
    /// atmosphere gap (surface radius → atmoRadius). Higher = taller columns.
    var volHeight: Float = 0.35
    /// How much a column's gaussian σ widens as it rises — the dome flare.
    var volSoftness: Float = 0.8
    /// Accumulated volume → alpha, so limb domes composite over the backdrop.
    var volAlphaLift: Float = 0.6
    /// 0 = flat SOFT_LILAC volume, 1 = full warm glow palette walk.
    var volTintMix: Float = 0.6
    /// Far-side lights ghosting through the glass at the refracted exit point.
    var volBackGhost: Float = 0.25

    // MARK: Glow orbs (3D style — inert while the glow style is classic)
    /// σ scale on each orb's packed world radius — the size dial.
    var orbSigmaScale: Float = 1.0
    /// Coverage compression gain: higher plateaus the core into a solid ball.
    var orbExposure: Float = 2.6
    /// Compressed orb body → emissive gain.
    var orbGain: Float = 0.9
    /// Uncompressed hot-core gain — pushes the core over 1.0 so bloom ignites.
    var orbHotGain: Float = 1.4
    /// Whiteness boost inside the core (skirt stays in palette).
    var orbCoreWhiteBoost: Float = 0.45
    /// Orb coverage → alpha, so limb orbs composite over the backdrop.
    var orbAlphaLift: Float = 0.85
    /// 3σ halo skirt weight around the orb body.
    var orbHaloWeight: Float = 0.35
    /// Seat elevation as a ratio of σ — how proud of the surface the ball sits.
    var orbElevRatio: Float = 1.6
    /// Orb sources' residual weight in the classic surface glow (the land seat).
    var orbSeatWeight: Float = 0.35

    // MARK: Spark burst (3D style — inert while the spark style is classic)
    /// Shell coverage compression gain.
    var burstExposure: Float = 1.6
    /// Compressed shell → emissive gain.
    var burstGain: Float = 0.85
    /// Uncompressed hot ring gain — bloom driver.
    var burstHotGain: Float = 0.8
    /// Shell coverage → alpha, so the expanding ring survives past the limb.
    var burstAlphaLift: Float = 0.6

    // MARK: CPU-side (consumed by EarthRenderer.makeUniforms, not the GPU struct)
    /// Sun direction components, normalized before upload.
    var sunX: Float = -0.45
    var sunY: Float = 0.55
    var sunZ: Float = 0.7
    var atmosphereStrength: Float = 0.1
    /// Physiological-sigh breath: inhale + exhale = period.
    var breathInhaleSeconds: Float = 4.0
    var breathExhaleSeconds: Float = 6.0
  }

  var values = Values()

  /// Per-frame GPU snapshot — 18 float4 packs, negligible next to the draw.
  var gpu: EarthTuningUniforms { values.gpu }

  func reset() { values = Values() }
}

extension EarthTuning.Values {
  var gpu: EarthTuningUniforms {
    EarthTuningUniforms(
      glowShape: .init(glowHaloWeight, glowExposure, glowLandMix, glowBrightness),
      haze: .init(hazeAlpha, hazeExponent, breathScaleAmp, shimmerAmp),
      continentBand: .init(continentLo, continentHi, inlandLo, inlandHi),
      coastBand: .init(coastLo, coastHi, backLo, backHi),
      iridescence: .init(iridescenceDriftSpeed, iridescenceDriftAmp, paletteStart, paletteSpan),
      glass: .init(fresnelBodyExponent, rimTightness, refractiveIndex, rimColorMix),
      backBleed: .init(backBleedBase, backBleedRimFade, backBleedTint, backBleedAlpha),
      emissiveA: .init(emissiveContinent, emissiveInland, emissiveSeaGlow, emissiveBackGlow),
      emissiveB: .init(emissiveRim, emissiveEdge, emissiveBody, emissiveShimmer),
      alphaA: .init(alphaContinent, alphaCoast, alphaRim, alphaSea),
      bloomA: .init(bloomThresholdLo, bloomThresholdHi, blurStepScale, bloomStrength),
      bloomB: .init(tonemapK, bloomAlphaLift, sparkFlash, coastGlow),
      lit: .init(litEmissive, litColorMix, volIntensity, volHeight),
      volumetric: .init(volSoftness, volAlphaLift, volTintMix, volBackGhost),
      orbShape: .init(orbSigmaScale, orbExposure, orbGain, orbHotGain),
      orbTint: .init(orbCoreWhiteBoost, orbAlphaLift, orbHaloWeight, orbElevRatio),
      burstShape: .init(burstExposure, burstGain, burstHotGain, burstAlphaLift),
      orbSeat: .init(orbSeatWeight, 0, 0, 0)
    )
  }
}
