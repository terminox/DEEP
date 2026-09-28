package io.appbeyond.freelance.deep.shared.header

import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import kotlin.math.abs
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * Ported from Deep/Deep/Shared/Components/CollapsibleHomeHeader.swift's
 * `CollapsibleHomeHeaderModifier` — the pure collapse fraction and every
 * interpolation derived from it.
 */
class HeaderCollapseTest {
  private fun near(expected: Float, actual: Float) = assertTrue(
    abs(expected - actual) < 0.0001f,
    "expected $expected but was $actual",
  )

  // MARK: - progress

  @Test
  @DisplayName("progress is zero at rest and one at the full collapse distance")
  fun progressSpansZeroToOne() {
    assertEquals(0f, HeaderCollapse.progress(0f))
    assertEquals(1f, HeaderCollapse.progress(HeaderCollapse.COLLAPSE_DISTANCE))
  }

  @Test
  @DisplayName("progress clamps past the collapse distance and below zero")
  fun progressClampsOutsideItsRange() {
    assertEquals(1f, HeaderCollapse.progress(HeaderCollapse.COLLAPSE_DISTANCE * 2))
    assertEquals(0f, HeaderCollapse.progress(-40f))
  }

  // MARK: - large title

  @Test
  @DisplayName("the large title is fully opaque until its fade begins")
  fun largeTitleOpaqueBeforeFadeBegins() {
    assertEquals(1f, HeaderCollapse.largeTitleOpacity(0f))
    assertEquals(1f, HeaderCollapse.largeTitleOpacity(0.45f))
  }

  @Test
  @DisplayName("the large title is fully gone once it has rolled clear")
  fun largeTitleGoneAfterRoll() {
    assertEquals(0f, HeaderCollapse.largeTitleOpacity(0.9f))
    assertEquals(0f, HeaderCollapse.largeTitleOpacity(1f))
  }

  @Test
  @DisplayName("the large title eases out through the middle of its fade")
  fun largeTitleEasesThroughMidFade() {
    near(0.5f, HeaderCollapse.largeTitleOpacity(0.675f))
  }

  @Test
  @DisplayName("the large title rolls upward in proportion to progress")
  fun largeTitleRollsUpward() {
    // `-progress * ROLL_TRAVEL` at progress = 0 is -0.0f, not 0.0f — numerically
    // equal but a distinct Float bit pattern, so this needs `near`, not
    // `assertEquals` (kotlin.test boxes to Any and -0.0f.equals(0.0f) is false).
    near(0f, HeaderCollapse.largeTitleOffsetY(0f))
    near(-20f, HeaderCollapse.largeTitleOffsetY(0.5f))
    assertEquals(-HeaderCollapse.ROLL_TRAVEL, HeaderCollapse.largeTitleOffsetY(1f))
  }

  // MARK: - compact title

  @Test
  @DisplayName("the compact title stays hidden until the large title has mostly cleared")
  fun compactTitleHiddenBeforeItsRiseBegins() {
    assertEquals(0f, HeaderCollapse.compactTitleOpacity(0f))
    assertEquals(0f, HeaderCollapse.compactTitleOpacity(0.5f))
  }

  @Test
  @DisplayName("the compact title is fully in place once collapsed")
  fun compactTitleFullyInPlaceOnceCollapsed() {
    assertEquals(1f, HeaderCollapse.compactTitleOpacity(0.95f))
    assertEquals(1f, HeaderCollapse.compactTitleOpacity(1f))
  }

  @Test
  @DisplayName("the compact title rises into place as progress finishes")
  fun compactTitleRisesIntoPlace() {
    assertEquals(HeaderCollapse.ROLL_TRAVEL, HeaderCollapse.compactTitleOffsetY(0f))
    near(20f, HeaderCollapse.compactTitleOffsetY(0.5f))
    assertEquals(0f, HeaderCollapse.compactTitleOffsetY(1f))
  }

  // MARK: - subtitle

  @Test
  @DisplayName("the subtitle fades out early, well before the large title finishes rolling")
  fun subtitleFadesOutEarly() {
    assertEquals(1f, HeaderCollapse.subtitleOpacity(0f))
    near(0.5f, HeaderCollapse.subtitleOpacity(0.2f))
    assertEquals(0f, HeaderCollapse.subtitleOpacity(0.4f))
  }

  // MARK: - title colour mix

  @Test
  @DisplayName("the title colour mix fraction tracks progress directly, with no easing")
  fun titleColorMixTracksProgressLinearly() {
    assertEquals(0f, HeaderCollapse.titleColorMixFraction(0f))
    assertEquals(0.3f, HeaderCollapse.titleColorMixFraction(0.3f))
    assertEquals(1f, HeaderCollapse.titleColorMixFraction(1f))
  }

  // MARK: - blur bar

  @Test
  @DisplayName("the blur bar fades in over the back half of the collapse")
  fun blurBarFadesInOverBackHalf() {
    assertEquals(0f, HeaderCollapse.barMaterialOpacity(0.5f))
    near(0.5f, HeaderCollapse.barMaterialOpacity(0.75f))
    assertEquals(1f, HeaderCollapse.barMaterialOpacity(1f))
  }

  // MARK: - legibility shadow

  @Test
  @DisplayName("the legibility shadow starts at full strength over the video")
  fun legibilityShadowStartsAtFullStrength() {
    near(0.35f, HeaderCollapse.legibilityShadowOpacity(0f))
  }

  @Test
  @DisplayName("the legibility shadow is gone by the collapse's midpoint")
  fun legibilityShadowGoneByMidpoint() {
    assertEquals(0f, HeaderCollapse.legibilityShadowOpacity(0.5f))
    assertEquals(0f, HeaderCollapse.legibilityShadowOpacity(1f))
  }

  @Test
  @DisplayName("the legibility shadow ramps down linearly before the midpoint")
  fun legibilityShadowRampsDownLinearly() {
    near(0.175f, HeaderCollapse.legibilityShadowOpacity(0.25f))
  }
}
