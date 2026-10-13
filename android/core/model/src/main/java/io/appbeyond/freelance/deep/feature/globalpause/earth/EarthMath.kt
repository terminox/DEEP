package io.appbeyond.freelance.deep.feature.globalpause.earth

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.asin
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt
import kotlin.math.tan

/*
 * The small amount of linear algebra the Earth needs, kept platform-free so
 * every number the shader is fed can be checked on the JVM.
 *
 * Conventions match iOS's `simd` usage in `Earth3D/` exactly, and GL's:
 * matrices are COLUMN-MAJOR (`m[col * 4 + row]`), vectors are columns, and
 * `a * b` applies `b` first. A [Mat4]'s backing array is therefore the very
 * float order a std140 `mat4` expects, and the order `glUniformMatrix4fv`
 * takes with `transpose = false`.
 */

/** A sphere-local or world-space 3-vector. */
data class Vec3(val x: Float, val y: Float, val z: Float) {
  operator fun plus(o: Vec3) = Vec3(x + o.x, y + o.y, z + o.z)
  operator fun minus(o: Vec3) = Vec3(x - o.x, y - o.y, z - o.z)
  operator fun times(s: Float) = Vec3(x * s, y * s, z * s)
  infix fun dot(o: Vec3): Float = x * o.x + y * o.y + z * o.z
  val length: Float get() = sqrt(this dot this)
  fun normalized(): Vec3 {
    val l = length
    return if (l > 0f) this * (1f / l) else this
  }

  companion object {
    val Zero = Vec3(0f, 0f, 0f)
  }
}

/** Degrees of latitude (north +) and longitude (east +). */
data class LatLon(val lat: Float, val lon: Float)

/**
 * Equirectangular lat/lon (degrees) → sphere-local unit vector.
 *
 * Latitude 0 is the equator; longitude 0 is +Z, the front of the orb facing
 * the camera. The one conversion every globe layer shares — glow store,
 * ripple overlay, country table, tap raycast — so screen projection and
 * shader glow can never drift apart. iOS's `GeoMath.sphereUnitVector`.
 */
fun sphereUnitVector(latDeg: Float, lonDeg: Float): Vec3 {
  val lat = latDeg * DEG
  val lon = lonDeg * DEG
  return Vec3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon))
}

/** The inverse of [sphereUnitVector] for a (near-)unit vector. */
fun latLonOf(unit: Vec3): LatLon {
  val lat = asin(unit.y.coerceIn(-1f, 1f))
  val lon = atan2(unit.x, unit.z)
  return LatLon(lat / DEG, lon / DEG)
}

/** A column-major 4×4 matrix. */
class Mat4(val m: FloatArray = identityArray()) {

  init {
    require(m.size == 16) { "Mat4 needs 16 floats" }
  }

  operator fun get(col: Int, row: Int): Float = m[col * 4 + row]

  /** `this * o`: applies [o] first. */
  operator fun times(o: Mat4): Mat4 {
    val r = FloatArray(16)
    for (col in 0 until 4) {
      for (row in 0 until 4) {
        var s = 0f
        for (k in 0 until 4) s += this[k, row] * o[col, k]
        r[col * 4 + row] = s
      }
    }
    return Mat4(r)
  }

  /** Transforms a direction (w = 0). */
  fun transformDirection(v: Vec3): Vec3 = Vec3(
    this[0, 0] * v.x + this[1, 0] * v.y + this[2, 0] * v.z,
    this[0, 1] * v.x + this[1, 1] * v.y + this[2, 1] * v.z,
    this[0, 2] * v.x + this[1, 2] * v.y + this[2, 2] * v.z,
  )

  /** Transforms a point (w = 1) with the perspective divide. */
  fun transformPoint(v: Vec3): Vec3 {
    val x = this[0, 0] * v.x + this[1, 0] * v.y + this[2, 0] * v.z + this[3, 0]
    val y = this[0, 1] * v.x + this[1, 1] * v.y + this[2, 1] * v.z + this[3, 1]
    val z = this[0, 2] * v.x + this[1, 2] * v.y + this[2, 2] * v.z + this[3, 2]
    val w = this[0, 3] * v.x + this[1, 3] * v.y + this[2, 3] * v.z + this[3, 3]
    return if (w != 0f && w != 1f) Vec3(x / w, y / w, z / w) else Vec3(x, y, z)
  }

  fun transposed(): Mat4 {
    val r = FloatArray(16)
    for (col in 0 until 4) for (row in 0 until 4) r[row * 4 + col] = this[col, row]
    return Mat4(r)
  }

  /** General inverse (cofactor expansion). Throws on a singular matrix. */
  fun inverse(): Mat4 {
    val a = m
    val inv = FloatArray(16)
    inv[0] = a[5] * a[10] * a[15] - a[5] * a[11] * a[14] - a[9] * a[6] * a[15] +
      a[9] * a[7] * a[14] + a[13] * a[6] * a[11] - a[13] * a[7] * a[10]
    inv[4] = -a[4] * a[10] * a[15] + a[4] * a[11] * a[14] + a[8] * a[6] * a[15] -
      a[8] * a[7] * a[14] - a[12] * a[6] * a[11] + a[12] * a[7] * a[10]
    inv[8] = a[4] * a[9] * a[15] - a[4] * a[11] * a[13] - a[8] * a[5] * a[15] +
      a[8] * a[7] * a[13] + a[12] * a[5] * a[11] - a[12] * a[7] * a[9]
    inv[12] = -a[4] * a[9] * a[14] + a[4] * a[10] * a[13] + a[8] * a[5] * a[14] -
      a[8] * a[6] * a[13] - a[12] * a[5] * a[10] + a[12] * a[6] * a[9]
    inv[1] = -a[1] * a[10] * a[15] + a[1] * a[11] * a[14] + a[9] * a[2] * a[15] -
      a[9] * a[3] * a[14] - a[13] * a[2] * a[11] + a[13] * a[3] * a[10]
    inv[5] = a[0] * a[10] * a[15] - a[0] * a[11] * a[14] - a[8] * a[2] * a[15] +
      a[8] * a[3] * a[14] + a[12] * a[2] * a[11] - a[12] * a[3] * a[10]
    inv[9] = -a[0] * a[9] * a[15] + a[0] * a[11] * a[13] + a[8] * a[1] * a[15] -
      a[8] * a[3] * a[13] - a[12] * a[1] * a[11] + a[12] * a[3] * a[9]
    inv[13] = a[0] * a[9] * a[14] - a[0] * a[10] * a[13] - a[8] * a[1] * a[14] +
      a[8] * a[2] * a[13] + a[12] * a[1] * a[10] - a[12] * a[2] * a[9]
    inv[2] = a[1] * a[6] * a[15] - a[1] * a[7] * a[14] - a[5] * a[2] * a[15] +
      a[5] * a[3] * a[14] + a[13] * a[2] * a[7] - a[13] * a[3] * a[6]
    inv[6] = -a[0] * a[6] * a[15] + a[0] * a[7] * a[14] + a[4] * a[2] * a[15] -
      a[4] * a[3] * a[14] - a[12] * a[2] * a[7] + a[12] * a[3] * a[6]
    inv[10] = a[0] * a[5] * a[15] - a[0] * a[7] * a[13] - a[4] * a[1] * a[15] +
      a[4] * a[3] * a[13] + a[12] * a[1] * a[7] - a[12] * a[3] * a[5]
    inv[14] = -a[0] * a[5] * a[14] + a[0] * a[6] * a[13] + a[4] * a[1] * a[14] -
      a[4] * a[2] * a[13] - a[12] * a[1] * a[6] + a[12] * a[2] * a[5]
    inv[3] = -a[1] * a[6] * a[11] + a[1] * a[7] * a[10] + a[5] * a[2] * a[11] -
      a[5] * a[3] * a[10] - a[9] * a[2] * a[7] + a[9] * a[3] * a[6]
    inv[7] = a[0] * a[6] * a[11] - a[0] * a[7] * a[10] - a[4] * a[2] * a[11] +
      a[4] * a[3] * a[10] + a[8] * a[2] * a[7] - a[8] * a[3] * a[6]
    inv[11] = -a[0] * a[5] * a[11] + a[0] * a[7] * a[9] + a[4] * a[1] * a[11] -
      a[4] * a[3] * a[9] - a[8] * a[1] * a[7] + a[8] * a[3] * a[5]
    inv[15] = a[0] * a[5] * a[10] - a[0] * a[6] * a[9] - a[4] * a[1] * a[10] +
      a[4] * a[2] * a[9] + a[8] * a[1] * a[6] - a[8] * a[2] * a[5]
    val det = a[0] * inv[0] + a[1] * inv[4] + a[2] * inv[8] + a[3] * inv[12]
    require(abs(det) > 1e-12f) { "Mat4 is singular" }
    val invDet = 1f / det
    for (i in 0 until 16) inv[i] *= invDet
    return Mat4(inv)
  }

  companion object {
    fun identityArray(): FloatArray = floatArrayOf(
      1f, 0f, 0f, 0f,
      0f, 1f, 0f, 0f,
      0f, 0f, 1f, 0f,
      0f, 0f, 0f, 1f,
    )

    val Identity: Mat4 get() = Mat4()

    fun translation(x: Float, y: Float, z: Float): Mat4 =
      Mat4(identityArray().also { it[12] = x; it[13] = y; it[14] = z })

    /** iOS `simd_float4x4(rotationAroundX:)`. */
    fun rotationX(a: Float): Mat4 {
      val c = cos(a)
      val s = sin(a)
      return Mat4(floatArrayOf(1f, 0f, 0f, 0f, 0f, c, s, 0f, 0f, -s, c, 0f, 0f, 0f, 0f, 1f))
    }

    /** iOS `simd_float4x4(rotationAroundY:)`, column for column. */
    fun rotationY(a: Float): Mat4 {
      val c = cos(a)
      val s = sin(a)
      return Mat4(floatArrayOf(c, 0f, s, 0f, 0f, 1f, 0f, 0f, -s, 0f, c, 0f, 0f, 0f, 0f, 1f))
    }

    /** iOS `simd_float4x4(rotationAroundZ:)`. */
    fun rotationZ(a: Float): Mat4 {
      val c = cos(a)
      val s = sin(a)
      return Mat4(floatArrayOf(c, s, 0f, 0f, -s, c, 0f, 0f, 0f, 0f, 1f, 0f, 0f, 0f, 0f, 1f))
    }

    /**
     * The OpenGL perspective matrix — z in [-1, 1] — exactly as iOS's
     * `perspectiveProjection` builds it (and `android.opengl.Matrix.perspectiveM`).
     * The shader reconstructs rays at ndc z −1 and +1, so this convention is
     * load-bearing, not cosmetic.
     */
    fun perspective(fovYRadians: Float, aspect: Float, near: Float, far: Float): Mat4 {
      val yScale = 1f / tan(fovYRadians * 0.5f)
      val xScale = yScale / aspect
      val zRange = far - near
      val zScale = -(far + near) / zRange
      val wzScale = -2f * far * near / zRange
      return Mat4(
        floatArrayOf(
          xScale, 0f, 0f, 0f,
          0f, yScale, 0f, 0f,
          0f, 0f, zScale, -1f,
          0f, 0f, wzScale, 0f,
        ),
      )
    }
  }
}

/** A unit quaternion (x, y, z, w) — only what the north-up model needs. */
data class Quat(val x: Float, val y: Float, val z: Float, val w: Float) {

  /** `this * o`: applies [o] first, as simd's `simd_quatf` product does. */
  operator fun times(o: Quat) = Quat(
    w * o.x + x * o.w + y * o.z - z * o.y,
    w * o.y - x * o.z + y * o.w + z * o.x,
    w * o.z + x * o.y - y * o.x + z * o.w,
    w * o.w - x * o.x - y * o.y - z * o.z,
  )

  /** The rotation matrix `simd_float4x4(quat)` produces. */
  fun toMat4(): Mat4 {
    val xx = x * x
    val yy = y * y
    val zz = z * z
    val xy = x * y
    val xz = x * z
    val yz = y * z
    val wx = w * x
    val wy = w * y
    val wz = w * z
    return Mat4(
      floatArrayOf(
        1f - 2f * (yy + zz), 2f * (xy + wz), 2f * (xz - wy), 0f,
        2f * (xy - wz), 1f - 2f * (xx + zz), 2f * (yz + wx), 0f,
        2f * (xz + wy), 2f * (yz - wx), 1f - 2f * (xx + yy), 0f,
        0f, 0f, 0f, 1f,
      ),
    )
  }

  companion object {
    fun axisAngle(axis: Vec3, angle: Float): Quat {
      val n = axis.normalized()
      val s = sin(angle * 0.5f)
      return Quat(n.x * s, n.y * s, n.z * s, cos(angle * 0.5f))
    }
  }
}

internal const val PI_F = PI.toFloat()
internal const val DEG = PI_F / 180f

/** GLSL `smoothstep`, NaN-safe for a zero-width band (returns a step). */
fun smoothstep(edge0: Float, edge1: Float, x: Float): Float {
  if (edge0 == edge1) return if (x < edge0) 0f else 1f
  val t = ((x - edge0) / (edge1 - edge0)).coerceIn(0f, 1f)
  return t * t * (3f - 2f * t)
}

/** `1 − (1 − x)³`, clamped — the decelerating arrival iOS uses everywhere here. */
fun easeOutCubic(x: Float): Float {
  val inv = 1f - x.coerceIn(0f, 1f)
  return 1f - inv * inv * inv
}

fun mix(a: Float, b: Float, t: Float): Float = a + (b - a) * t

/** Swift's `Float.remainder(dividingBy:)`: IEEE remainder, result in [−d/2, d/2]. */
fun ieeeRemainder(x: Float, d: Float): Float = Math.IEEEremainder(x.toDouble(), d.toDouble()).toFloat()
