import simd

/// Equirectangular lat/lon (degrees) → sphere-local unit vector.
///
/// Convention: latitude 0 = equator, longitude 0 = +Z (front of orb facing
/// the camera). This is the one conversion every globe layer shares — glow
/// store, ripple overlay, and the country table — so screen-space projection
/// and shader-space glow can never drift apart.
func sphereUnitVector(latDeg: Float, lonDeg: Float) -> SIMD3<Float> {
  let latR = latDeg * .pi / 180
  let lonR = lonDeg * .pi / 180
  return SIMD3<Float>(
    cos(latR) * sin(lonR),
    sin(latR),
    cos(latR) * cos(lonR)
  )
}
