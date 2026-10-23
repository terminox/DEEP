package io.appbeyond.freelance.deep.feature.globalpause.earth

import org.junit.jupiter.api.Test
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt
import kotlin.math.tan
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

/**
 * Ported behaviour from Deep/Deep/Features/GlobalPause/Earth3D/EarthRenderer.swift (the
 * `simd_float4x4` helpers and `perspectiveProjection`) and EarthRendererTypes.swift
 * (`EarthRendererConstants`). iOS has no tests for these; these are new, written from the
 * iOS behaviour.
 *
 * What it guards: the column-major matrix conventions the shader reads the uniform block
 * with, the quaternion the north-up model composes, the GL projection the shader
 * reconstructs rays through, and the orb's on-screen size every overlay hangs off.
 */
class EarthMatricesTest {

  private fun assertMat(expected: Mat4, actual: Mat4, tolerance: Float = 1e-5f) {
    for (i in 0 until 16) assertEquals(expected.m[i], actual.m[i], tolerance, "element $i")
  }

  private fun assertVec(expected: Vec3, actual: Vec3, tolerance: Float = 1e-5f) {
    assertEquals(expected.x, actual.x, tolerance, "x of $actual")
    assertEquals(expected.y, actual.y, tolerance, "y of $actual")
    assertEquals(expected.z, actual.z, tolerance, "z of $actual")
  }

  private val angles = listOf(-2.9f, -1.1f, -0.3f, 0f, 0.41f, 1.2f, PI_F / 2f, 3.0f)

  @Test
  fun timesAppliesTheRightOperandFirst() {
    val m = Mat4.translation(1f, 0f, 0f) * Mat4.rotationZ(PI_F / 2f)
    // Rotate (1,0,0) to (0,1,0) first, then translate.
    assertVec(Vec3(1f, 1f, 0f), m.transformPoint(Vec3(1f, 0f, 0f)))
  }

  @Test
  fun backingArrayIsColumnMajor() {
    val t = Mat4.translation(3f, 4f, 5f)
    assertEquals(3f, t.m[12])
    assertEquals(4f, t.m[13])
    assertEquals(5f, t.m[14])
    assertEquals(3f, t[3, 0])
  }

  @Test
  fun inverseRoundTripsTheViewProjection() {
    for (aspect in listOf(0.5f, 0.86f, 1f, 2.1f)) {
      val vp = EarthGeometry.viewProjection(aspect)
      assertMat(Mat4.Identity, vp * vp.inverse(), 1e-4f)
      assertMat(Mat4.Identity, vp.inverse() * vp, 1e-4f)
    }
  }

  @Test
  fun inverseOfARotationIsItsTranspose() {
    val r = Mat4.rotationZ(0.4f) * Mat4.rotationX(-1.1f) * Mat4.rotationY(2.2f)
    assertMat(r.transposed(), r.inverse())
  }

  @Test
  fun inverseRejectsASingularMatrix() {
    assertFailsWith<IllegalArgumentException> { Mat4(FloatArray(16)).inverse() }
  }

  @Test
  fun quaternionAboutXMatchesRotationX() {
    for (a in angles) assertMat(Mat4.rotationX(a), Quat.axisAngle(Vec3(1f, 0f, 0f), a).toMat4())
  }

  @Test
  fun quaternionAboutZMatchesRotationZ() {
    for (a in angles) assertMat(Mat4.rotationZ(a), Quat.axisAngle(Vec3(0f, 0f, 1f), a).toMat4())
  }

  /**
   * iOS's `simd_float4x4(rotationAroundY:)` has columns (c,0,s), (0,1,0), (−s,0,c): it
   * turns +Z toward −X, i.e. it is the right-handed rotation by −a. The quaternion (and
   * `simd_quatf`) is right-handed: +Z toward +X. [Mat4.rotationY] copies the iOS helper
   * column for column, so it equals the quaternion of the NEGATED angle. The north-up
   * model never uses the helper (it composes quaternions), so this asymmetry is iOS's
   * and harmless — but anyone swapping one for the other flips the spin.
   */
  @Test
  fun rotationYMirrorsTheIosHelperWhichIsTheQuaternionOfTheNegatedAngle() {
    for (a in angles) assertMat(Mat4.rotationY(a), Quat.axisAngle(Vec3(0f, 1f, 0f), -a).toMat4())

    val a = 0.7f
    val helper = Mat4.rotationY(a)
    val quat = Quat.axisAngle(Vec3(0f, 1f, 0f), a).toMat4()
    assertEquals(sin(a), helper.m[2], 1e-6f)
    assertEquals(-sin(a), quat.m[2], 1e-6f)
    assertVec(Vec3(-sin(a), 0f, cos(a)), helper.transformDirection(Vec3(0f, 0f, 1f)))
    assertVec(Vec3(sin(a), 0f, cos(a)), quat.transformDirection(Vec3(0f, 0f, 1f)))
  }

  @Test
  fun quaternionProductComposesLikeMatrices() {
    val qa = Quat.axisAngle(Vec3(1f, 0f, 0f), 0.6f)
    val qb = Quat.axisAngle(Vec3(0f, 1f, 0f), -1.7f)
    val qc = Quat.axisAngle(Vec3(0.3f, -0.5f, 0.8f), 2.3f)
    assertMat(qa.toMat4() * qb.toMat4(), (qa * qb).toMat4())
    assertMat(qc.toMat4() * qa.toMat4() * qb.toMat4(), (qc * qa * qb).toMat4())
  }

  @Test
  fun perspectiveMatchesTheGlFormula() {
    val fov = PI / 6
    val aspect = 0.75
    val n = 0.1
    val f = 100.0
    val p = Mat4.perspective(fov.toFloat(), aspect.toFloat(), n.toFloat(), f.toFloat())
    val focal = 1 / tan(fov / 2)
    val expected = FloatArray(16).also {
      it[0] = (focal / aspect).toFloat()
      it[5] = focal.toFloat()
      it[10] = ((f + n) / (n - f)).toFloat()
      it[11] = -1f
      it[14] = (2 * f * n / (n - f)).toFloat()
    }
    for (i in 0 until 16) assertEquals(expected[i], p.m[i], 1e-5f, "element $i")
  }

  @Test
  fun perspectiveMapsNearAndFarToNdcMinusOneAndOne() {
    val p = Mat4.perspective(EarthGeometry.CAMERA_FOV_Y, 1f, EarthGeometry.NEAR, EarthGeometry.FAR)
    assertEquals(-1f, p.transformPoint(Vec3(0f, 0f, -EarthGeometry.NEAR)).z, 1e-5f)
    assertEquals(1f, p.transformPoint(Vec3(0f, 0f, -EarthGeometry.FAR)).z, 1e-4f)
  }

  @Test
  fun orbFillsAboutTwentyTwoPercentOfTheHeight() {
    // tan(asin(R/D)) = (R/D)/sqrt(1 − (R/D)²), over tan(fov/2), halved into a fraction of height.
    val s = 1.0 / 8.5
    val expected = (s / sqrt(1 - s * s)) / tan(PI / 12) * 0.5
    assertEquals(0.22107, expected, 1e-5)
    assertEquals(expected.toFloat(), EarthGeometry.orbScreenRadiusFractionOfHeight, 1e-6f)
    assertEquals(2 * expected.toFloat(), EarthGeometry.orbFillOfSide, 1e-6f)
  }

  /** The silhouette's tangent point projects exactly at that fraction, whatever the aspect. */
  @Test
  fun theLimbProjectsAtTheOrbsScreenRadius() {
    val z = 1f / EarthGeometry.CAMERA_DISTANCE
    val limb = Vec3(0f, sqrt(1f - z * z), z)
    for (aspect in listOf(0.56f, 1f, 1.8f)) {
      val ndc = EarthGeometry.viewProjection(aspect).transformPoint(limb)
      assertEquals(2f * EarthGeometry.orbScreenRadiusFractionOfHeight, ndc.y, 1e-5f)
    }
  }

  @Test
  fun worldUnitsPerPixel() {
    val expected = (2 * tan(PI / 12) * 8.5 / 600).toFloat()
    assertEquals(expected, EarthGeometry.worldUnitsPerPixel(600), 1e-7f)
    assertEquals(expected * 600f, EarthGeometry.worldUnitsPerPixel(0), 1e-5f)
    assertEquals(2f * EarthGeometry.worldUnitsPerPixel(1200), EarthGeometry.worldUnitsPerPixel(600), 1e-7f)
  }

  @Test
  fun bloomIsAFixedHeightAtTheTargetsAspect() {
    assertEquals(337 to 600, EarthGeometry.bloomSize(1080, 1920))
    assertEquals(600 to 600, EarthGeometry.bloomSize(512, 512))
    assertEquals(1200 to 600, EarthGeometry.bloomSize(2000, 1000))
    assertEquals(1 to 600, EarthGeometry.bloomSize(1, 10_000))
  }

  @Test
  fun scalarHelpers() {
    assertEquals(0f, smoothstep(0f, 1f, -1f))
    assertEquals(0.5f, smoothstep(0f, 1f, 0.5f))
    assertEquals(1f, smoothstep(0f, 1f, 2f))
    assertEquals(0f, smoothstep(1f, 1f, 0.5f))
    assertEquals(1f, smoothstep(1f, 1f, 1f))
    assertEquals(0.875f, easeOutCubic(0.5f))
    assertEquals(1f, easeOutCubic(3f))
    assertEquals(0f, easeOutCubic(-1f))
    assertEquals(2.5f, mix(2f, 4f, 0.25f))
    assertEquals(1f, ieeeRemainder(1f, 2f * PI_F), 1e-6f)
    assertEquals(4f - 2f * PI_F, ieeeRemainder(4f, 2f * PI_F), 1e-6f)
    assertTrue(ieeeRemainder(-4f, 2f * PI_F) > 0f)
  }
}
