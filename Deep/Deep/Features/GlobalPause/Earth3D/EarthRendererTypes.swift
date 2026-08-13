import simd

// Mirrored byte-for-byte in EarthSurface.metal (GlowSourceGPU, EarthUniforms)
// and Shaders/EarthTuningShared.h (EarthTuningUniforms). Keep struct layouts
// in sync.

struct GlowSourceGPU {
  // xyz = unit position on sphere (lat/lon converted), w = intensity 0...1
  var positionAndIntensity: SIMD4<Float>
  // x = angular radius (radians), y = whiteness 0...1 (join sparks push the
  // glow toward moon-cream; steady sources send 0), zw = reserved
  var radiusPacked: SIMD4<Float>
}

struct EarthUniforms {
  var inverseViewProj: simd_float4x4
  var cameraPosition: SIMD4<Float>
  var sphereOrientation: simd_float4x4
  var sunDirection: SIMD4<Float>
  // x = time, y = breathPhase 0..1, z = aspect, w = glowCount
  var params: SIMD4<Float>
  // xyz = sphere center (world), w = sphere radius
  var sphereData: SIMD4<Float>
  // x = atmosphere outer radius, y = atmosphere strength, z = baseline emissive, w = reserved
  var atmosphereData: SIMD4<Float>
}

/// Live-tunable look parameters, uploaded once per frame beside `EarthUniforms`
/// (surface pass fragment buffer 2; every bloom-chain pass fragment buffer 0).
///
/// Ships in every configuration: Release renders with `EarthTuning.Values()`
/// defaults, which reproduce the previously hardcoded shader literals exactly —
/// gating the *layout* behind `#if DEBUG` would make Debug and Release compile
/// different shaders, so only the tuning panel UI is DEBUG-only.
///
/// Every slot is a float4 so the Swift stride equals the Metal size with no
/// padding ambiguity (asserted in `EarthRenderer.buildBuffers`). Component
/// meanings are documented per slot; defaults live once, in
/// `EarthTuning.Values`.
struct EarthTuningUniforms {
  /// x = glow halo skirt weight, y = glow exposure (compression gain),
  /// z = glow→land color mix, w = glow land brightness gain
  var glowShape: SIMD4<Float>
  /// x = atmosphere haze alpha, y = haze falloff exponent,
  /// z = whole-orb breath scale amplitude, w = breath shimmer amplitude
  var haze: SIMD4<Float>
  /// Continent mask smoothstep bands over landRaw:
  /// x = continent lo, y = continent hi, z = inland lo, w = inland hi
  var continentBand: SIMD4<Float>
  /// x = coast halo lo, y = coast halo hi,
  /// z = back-bleed continent lo, w = back-bleed continent hi
  var coastBand: SIMD4<Float>
  /// x = palette drift speed, y = palette drift amplitude,
  /// z = palette walk start, w = palette walk span
  var iridescence: SIMD4<Float>
  /// x = fresnel body exponent, y = rim tightness (scales the coupled
  /// 10:18:28 rim/edge/alpha exponent triple proportionally),
  /// z = refractive index, w = rim color dispersion mix
  var glass: SIMD4<Float>
  /// x = back-bleed base, y = back-bleed rim fade,
  /// z = back-bleed tint palette position, w = back-bleed alpha weight
  var backBleed: SIMD4<Float>
  /// Emissive weights: x = continent, y = inland boost, z = sea glow, w = back glow
  var emissiveA: SIMD4<Float>
  /// Emissive weights: x = rim, y = dispersion edge, z = body gleam, w = shimmer
  var emissiveB: SIMD4<Float>
  /// Alpha weights: x = continent, y = coast halo, z = rim, w = sea glow
  var alphaA: SIMD4<Float>
  /// x = bloom threshold lo, y = bloom threshold hi,
  /// z = blur step scale (texels), w = bloom strength
  var bloomA: SIMD4<Float>
  /// x = tonemap compression k, y = bloom alpha lift,
  /// z = spark whiteness → brightness flash, w = coast glow weight
  var bloomB: SIMD4<Float>
  /// Independent lit-land term, decoupled from the base land emissive:
  /// x = lit emissive weight, y = lit color mix (palette → warm glow),
  /// z = volumetric glow master gain, w = volumetric column scale height
  var lit: SIMD4<Float>
  /// Volumetric 3D glow shell: x = column flare with height (σ widen),
  /// y = accumulated volume → alpha lift, z = tint mix (flat lilac → warm walk),
  /// w = far-side ghost weight through the glass body
  var volumetric: SIMD4<Float>
}

enum EarthRendererConstants {
  static let maxGlowSources: Int = 64
  static let sphereRadius: Float = 1.0
  static let atmosphereRadius: Float = 1.06
  // Camera distance is chosen so the orb + atmosphere shell fit *inside* the
  // MTKView with margin for bloom spill — both for the taller-than-wide
  // (~0.86 aspect) hero frame and for landscape/square previews.
  //
  // Math: silhouette half-angle = asin(atmoRadius / distance). For atmoRadius
  // 1.06 and distance 5.5 → 11.1°. With fovY=30° (half=15°) and aspect 0.86
  // (horizontal half-fov ≈ 12.97°), the atmosphere reaches ~75% of NDC
  // vertically and ~87% horizontally, leaving headroom for bloom.
  static let cameraDistance: Float = 8.5
  static let cameraFovYRadians: Float = .pi / 6
  // Earth axial tilt — matches design plan ("23.5° tilt") for the off-axis feel.
  static let axialTiltRadians: Float = 23.5 * .pi / 180

  /// Bloom-chain render height in pixels, fixed across drawable sizes. The
  /// blur kernel steps a fixed number of texels, so tying the bloom textures
  /// to the drawable makes the glow a constant number of PIXELS —
  /// proportionally ~3× wider on the 200pt card than in the fullscreen lobby,
  /// which popped visibly when the card-lift transition swapped render scales
  /// at its endpoints. A fixed bloom resolution makes the halo a constant
  /// fraction of view height instead (scale-invariant). 600 = the card's
  /// drawable height (200pt @3x), preserving the card's original look.
  static let bloomReferenceHeight: Int = 600

  /// Orb's screen-space radius as a fraction of the view *height* in points.
  /// The perspective projection is fov-Y based, so vertical extent is the
  /// invariant — multiply this by `geo.size.height` to get the on-screen radius.
  /// Used by the SwiftUI ripple overlay so its rings line up exactly with the shader.
  static var orbScreenRadiusFractionOfHeight: Float {
    let angular = asin(sphereRadius / cameraDistance)
    let halfFov = cameraFovYRadians / 2
    let ndcRadius = tan(angular) / tan(halfFov)
    return ndcRadius * 0.5
  }
}
