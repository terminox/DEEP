package io.appbeyond.freelance.deep.feature.globalpause.earth

/**
 * One star of the Global Pause night sky, baked at generation: every field a
 * unit fraction the drawing scales by the tuning at draw time. iOS's
 * `NightSkyStar`.
 */
data class NightSkyStar(
  /** 0…1 across the width. */
  val x: Float,
  /** 0…1 down the height. */
  val y: Float,
  val sizeT: Float,
  val brightT: Float,
  /** 0…2π twinkle phase. */
  val phase: Float,
  /** 0.6…1.4 on the base twinkle rate. */
  val rateJitter: Float,
  /** Position on the cream → cool tint ramp. */
  val tintT: Float,
  /** Twinkles when below the tuning's share. */
  val twinkleT: Float,
)

/**
 * The deterministic star field: SplitMix64 from the seed, so a seed always
 * reproduces the same constellation — the very one iOS draws for it (same
 * generator, same draw order, same 24-bit unit mapping).
 */
object NightSkyStarField {

  fun stars(seed: Int, count: Int): List<NightSkyStar> {
    val rng = SplitMix64(seed.toLong() + 0x5EED)
    return List(count) {
      NightSkyStar(
        x = rng.unit(),
        y = rng.unit(),
        sizeT = rng.unit(),
        brightT = rng.unit(),
        phase = rng.unit() * 2f * PI_F,
        rateJitter = 0.6f + rng.unit() * 0.8f,
        tintT = rng.unit(),
        twinkleT = rng.unit(),
      )
    }
  }

  /** SplitMix64 with Swift's wrapping arithmetic (Kotlin Long already wraps). */
  internal class SplitMix64(private var state: Long) {
    fun next(): Long {
      state += -0x61c8864680b583ebL // 0x9E3779B97F4A7C15
      var z = state
      z = (z xor (z ushr 30)) * -0x40a7b892e31b1a47L // 0xBF58476D1CE4E5B9
      z = (z xor (z ushr 27)) * -0x6b2fb644ecceee15L // 0x94D049BB133111EB
      return z xor (z ushr 31)
    }

    /** Uniform in [0, 1) from the top 24 bits. */
    fun unit(): Float = (next() ushr 40).toFloat() / (1 shl 24).toFloat()
  }
}
