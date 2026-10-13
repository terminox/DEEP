package io.appbeyond.freelance.deep.feature.globalpause.earth

import kotlin.math.asin
import kotlin.math.tan

/**
 * The fixed geometry of the Earth scene — iOS's `EarthRendererConstants`.
 *
 * The camera sits on +Z at [CAMERA_DISTANCE] looking at the origin, with a
 * fov-Y perspective, so the orb's on-screen size is a fixed fraction of the
 * view's HEIGHT ([orbScreenRadiusFractionOfHeight]) whatever its width. Every
 * overlay — ripples, the reveal capsule, the halo behind the orb — hangs off
 * that one number, as does the seat the lounge card gives the globe.
 */
object EarthGeometry {
  const val MAX_GLOW_SOURCES = 64
  const val SPHERE_RADIUS = 1f
  const val ATMOSPHERE_RADIUS = 1.06f
  const val CAMERA_DISTANCE = 8.5f
  const val CAMERA_FOV_Y = PI_F / 6f
  const val NEAR = 0.1f
  const val FAR = 100f

  /** Earth's axial tilt, composed as a Z rotation over the user's orientation. */
  const val AXIAL_TILT = 23.5f * DEG

  /**
   * The bloom chain's render height in pixels, fixed across target sizes so
   * the halo is a constant FRACTION of the view rather than a constant number
   * of pixels — otherwise it pops as the card lift changes the render size.
   * 600 is the iOS card's drawable height (200pt at 3x).
   */
  const val BLOOM_REFERENCE_HEIGHT = 600

  /** The orb's on-screen radius as a fraction of the view height (≈ 0.2211). */
  val orbScreenRadiusFractionOfHeight: Float = run {
    val angular = asin(SPHERE_RADIUS / CAMERA_DISTANCE)
    val ndcRadius = tan(angular) / tan(CAMERA_FOV_Y / 2f)
    ndcRadius * 0.5f
  }

  /** The share of a square view's side the orb's diameter fills (≈ 0.4421). */
  val orbFillOfSide: Float get() = 2f * orbScreenRadiusFractionOfHeight

  /** World units per target pixel at the sphere's distance, for a target [heightPx] tall. */
  fun worldUnitsPerPixel(heightPx: Int): Float =
    2f * tan(CAMERA_FOV_Y / 2f) * CAMERA_DISTANCE / heightPx.coerceAtLeast(1)

  /** The camera: perspective × a view that backs off along +Z. */
  fun viewProjection(aspect: Float): Mat4 =
    Mat4.perspective(CAMERA_FOV_Y, aspect, NEAR, FAR) * Mat4.translation(0f, 0f, -CAMERA_DISTANCE)

  /** The bloom chain's (width, height) for a target of the given size. */
  fun bloomSize(targetWidth: Int, targetHeight: Int): Pair<Int, Int> {
    val h = BLOOM_REFERENCE_HEIGHT
    val w = ((targetWidth.toDouble() / targetHeight.coerceAtLeast(1)) * h).toInt().coerceAtLeast(1)
    return w to h
  }
}
