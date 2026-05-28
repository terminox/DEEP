import simd

// Mirrored byte-for-byte in EarthSurface.metal. Keep struct layouts in sync.

struct GlowSourceGPU {
  // xyz = unit position on sphere (lat/lon converted), w = intensity 0...1
  var positionAndIntensity: SIMD4<Float>
  // x = angular radius (radians), yzw = reserved for future tinting
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
