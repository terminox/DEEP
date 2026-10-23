package io.appbeyond.freelance.deep.shared.header

/**
 * Ported from Deep/Deep/Shared/Components/CollapsibleHomeHeader.swift's
 * `CollapsibleHomeHeaderModifier` — the pure numbers behind the home header's
 * collapse, kept apart from the `GeometryReader`/scroll-offset plumbing that
 * feeds them. Every value here is a function of [progress] alone, in points
 * (dp on Android), matching the SwiftUI source exactly (including its
 * `smoothstep` easing) so the two platforms roll the title in step.
 */
object HeaderCollapse {
  /** Scroll distance over which the title fully collapses onto the bar. */
  const val COLLAPSE_DISTANCE = 110f

  /** How far the large/compact titles travel vertically as they roll. */
  const val ROLL_TRAVEL = 40f

  /** 0 = expanded large title at rest, 1 = fully collapsed compact bar. */
  fun progress(scrollOffset: Float): Float = (scrollOffset / COLLAPSE_DISTANCE).coerceIn(0f, 1f)

  /** Large title's fade-out as it rolls up and clips out of the bar. */
  fun largeTitleOpacity(progress: Float): Float = 1f - smoothstep(0.45f, 0.9f, progress)

  /** Large title's upward roll, in points — negative is up. */
  fun largeTitleOffsetY(progress: Float): Float = -progress * ROLL_TRAVEL

  /** Compact title's fade-in as it rises into the bar from just below. */
  fun compactTitleOpacity(progress: Float): Float = smoothstep(0.5f, 0.95f, progress)

  /** Compact title's rise into place, in points — settles at 0. */
  fun compactTitleOffsetY(progress: Float): Float = (1f - progress) * ROLL_TRAVEL

  /** Subtitle's fade-out — clears first, well before the large title finishes
   * rolling, so the compact bar reads as the name alone. */
  fun subtitleOpacity(progress: Float): Float = 1f - smoothstep(0f, 0.4f, progress)

  /** The fraction a caller mixes white (over the hero) toward deepPlum (on the
   * blurred bar) by. Unlike the other interpolations this tracks [progress]
   * directly, with no easing — `Color.white.mix(with:by:)` in the SwiftUI
   * source takes `progress` itself. */
  fun titleColorMixFraction(progress: Float): Float = progress

  /** Progressive-blur bar's opacity ramp, trailing the compact title in so the
   * bar never appears before the title that belongs on it. */
  fun barMaterialOpacity(progress: Float): Float = smoothstep(0.5f, 1f, progress)

  /** Legibility drop-shadow strength over the video, gone by the collapse's
   * midpoint where the title has moved onto the opaque-enough blur. */
  fun legibilityShadowOpacity(progress: Float): Float =
    0.35f * (1f - (progress / 0.5f).coerceIn(0f, 1f))

  /** Smooth Hermite ease between two edges, clamped to 0…1. */
  private fun smoothstep(edge0: Float, edge1: Float, x: Float): Float {
    val t = ((x - edge0) / (edge1 - edge0)).coerceIn(0f, 1f)
    return t * t * (3f - 2f * t)
  }
}
