package io.appbeyond.freelance.deep.feature.compassion

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathFillType
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.PathBuilder
import androidx.compose.ui.graphics.vector.PathData
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.moonCream
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.min
import kotlin.math.sin

/** Circle-to-cubic control factor: 4/3 * tan(π/8). */
private const val CIRCLE_K = 0.5523f

/**
 * The glyphs the Compassion Portfolio needs, drawn in the same hand as
 * [io.appbeyond.freelance.deep.feature.appshell.DeepIcons] and
 * [io.appbeyond.freelance.deep.feature.profile.ProfileIcons].
 *
 * iOS reaches for SF Symbols here: the cause and project motifs in
 * `CompassionLibrary` (`bird.fill`, `flame.fill`, `pawprint.fill`, …), the
 * partner marks, and the small UI glyphs on the cards and the donate keypad.
 * Material's set is off-limits for the same reason the tab bar draws its own —
 * DESIGN.md asks for soft, rounded glyphs, and a Material icon on a DEEP card
 * makes it read as a different, cheaper product — and the extended Material
 * icons artifact is not a dependency here anyway.
 *
 * Each glyph sits on a 24dp canvas, untinted, so `Icon` colours it at the call
 * site. SF's `.fill` symbols become solid silhouettes ([filledIcon]); interior
 * detail (book bands, a bird's eye, the hexagon grid) is cut out with
 * [PathFillType.EvenOdd] rather than stroked, so the glyph stays one solid
 * shape from 10dp to 60dp. Symbols without `.fill` stay 1.5-stroke line icons
 * ([lineIcon]), matching the tab bar.
 *
 * The builders are repeated rather than shared because the other icon objects
 * keep theirs private; hoist all three into `shared/` if a fourth feature needs
 * glyphs.
 */
object CompassionIcons {

  // MARK: - Cause motifs

  /** `bird.fill` — the wildlife cause motif. A songbird facing right, eye and wing cut out. */
  val BirdFill: ImageVector = filledIcon("CompassionBirdFill", PathFillType.EvenOdd) {
    moveTo(21.25f, 8.25f)
    lineTo(18.5f, 9.75f)
    curveTo(19f, 14.5f, 15.5f, 18.5f, 10.5f, 18.75f)
    lineTo(4.5f, 19.6f)
    quadTo(3.25f, 19.8f, 3.9f, 18.8f)
    lineTo(7f, 15.5f)
    curveTo(8.5f, 11.5f, 10.5f, 9f, 12.4f, 7.6f)
    curveTo(13f, 5.8f, 14.2f, 5.25f, 15.5f, 5.25f)
    curveTo(16.9f, 5.25f, 18f, 6f, 18.4f, 7f)
    close()
    // Eye.
    circle(15.75f, 8f, 0.9f)
    // Wing, a thin crescent across the body.
    moveTo(9.25f, 14.25f)
    curveTo(11.5f, 11.75f, 14.5f, 11.25f, 16.25f, 12.25f)
    curveTo(14.3f, 12.6f, 11.9f, 13.4f, 9.25f, 14.25f)
    close()
  }

  /** `cross.fill` — the health cause motif. A rounded medical plus. */
  val CrossFill: ImageVector = filledIcon("CompassionCrossFill") {
    roundedPolygon(
      8.75f, 3.5f, 1.75f,
      15.25f, 3.5f, 1.75f,
      15.25f, 8.75f, 1f,
      20.5f, 8.75f, 1.75f,
      20.5f, 15.25f, 1.75f,
      15.25f, 15.25f, 1f,
      15.25f, 20.5f, 1.75f,
      8.75f, 20.5f, 1.75f,
      8.75f, 15.25f, 1f,
      3.5f, 15.25f, 1.75f,
      3.5f, 8.75f, 1.75f,
      8.75f, 8.75f, 1f,
    )
  }

  /** `book.fill` — the education cause motif. An open book, two pages either side of the spine. */
  val BookFill: ImageVector = filledIcon("CompassionBookFill") {
    // Left page.
    moveTo(11.25f, 6.6f)
    curveTo(9.6f, 5.2f, 7.2f, 4.6f, 4.75f, 4.85f)
    quadTo(3.5f, 5f, 3.5f, 6.25f)
    lineTo(3.5f, 17.25f)
    quadTo(3.5f, 18.5f, 4.75f, 18.4f)
    curveTo(7.2f, 18.25f, 9.6f, 18.6f, 11.25f, 19.75f)
    close()
    // Right page, mirrored.
    moveTo(12.75f, 6.6f)
    curveTo(14.4f, 5.2f, 16.8f, 4.6f, 19.25f, 4.85f)
    quadTo(20.5f, 5f, 20.5f, 6.25f)
    lineTo(20.5f, 17.25f)
    quadTo(20.5f, 18.5f, 19.25f, 18.4f)
    curveTo(16.8f, 18.25f, 14.4f, 18.6f, 12.75f, 19.75f)
    close()
  }

  /** `leaf.fill` — the environment cause motif. A leaf tipped up-right on its stem, midrib cut out. */
  val LeafFill: ImageVector = filledIcon("CompassionLeafFill", PathFillType.EvenOdd) {
    // Stem and blade as one outline, so the midrib cut-out stays the only hole.
    moveTo(3.97f, 18.97f)
    lineTo(6.9f, 16f)
    curveTo(5.5f, 10.5f, 9f, 4.75f, 19.75f, 4.25f)
    curveTo(19.25f, 15f, 13.5f, 18.5f, 8f, 17.1f)
    lineTo(5.03f, 20.03f)
    arcTo(0.75f, 0.75f, 0f, isMoreThanHalf = false, isPositiveArc = true, x1 = 3.97f, y1 = 18.97f)
    close()
    // Midrib, tapering at both ends.
    moveTo(8.75f, 15.25f)
    curveTo(11.5f, 12f, 14.2f, 9.2f, 17.25f, 6.75f)
    curveTo(15.1f, 10.1f, 12.4f, 12.9f, 8.75f, 15.25f)
    close()
  }

  /** `house.fill` — the shelter cause motif. A pitched house with its door notched out. */
  val HouseFill: ImageVector = filledIcon("CompassionHouseFill") {
    roundedPolygon(
      12f, 3.5f, 1.5f,
      19.75f, 10.25f, 1.5f,
      19.75f, 20f, 1.5f,
      14.25f, 20f, 0.5f,
      14.25f, 15.25f, 1.25f,
      9.75f, 15.25f, 1.25f,
      9.75f, 20f, 0.5f,
      4.25f, 20f, 1.5f,
      4.25f, 10.25f, 1.5f,
    )
  }

  /**
   * `heart.fill` — the Compassion heart: balances, send-a-heart, the community
   * pool. The same outline as `HeartShape` in `shared/components/HeartBurst.kt`.
   */
  val HeartFill: ImageVector = filledIcon("CompassionHeartFill") { heart() }

  // MARK: - Project motifs

  /** `flame.fill` — a project motif. A flame with its inner tongue cut out. */
  val FlameFill: ImageVector = filledIcon("CompassionFlameFill", PathFillType.EvenOdd) {
    moveTo(12f, 21f)
    curveTo(8.13f, 21f, 5.5f, 18.4f, 5.5f, 14.75f)
    curveTo(5.5f, 10.75f, 10f, 8.5f, 12f, 3f)
    curveTo(15f, 6.5f, 18.5f, 9.75f, 18.5f, 14.75f)
    curveTo(18.5f, 18.4f, 15.87f, 21f, 12f, 21f)
    close()
    // Inner tongue.
    moveTo(12f, 19.25f)
    curveTo(10.2f, 19.25f, 9f, 18f, 9f, 16.4f)
    curveTo(9f, 14.4f, 10.75f, 13.6f, 12f, 11.25f)
    curveTo(13.25f, 13.6f, 15f, 14.4f, 15f, 16.4f)
    curveTo(15f, 18f, 13.8f, 19.25f, 12f, 19.25f)
    close()
  }

  /** `moon.stars.fill` — a project motif. A crescent with two sparkles in its hollow. */
  val MoonStarsFill: ImageVector = filledIcon("CompassionMoonStarsFill") {
    // Outer edge r = 8 around the lower left; inner edge r = 7 bites the upper right.
    moveTo(11.5f, 3.75f)
    arcTo(8f, 8f, 0f, isMoreThanHalf = true, isPositiveArc = false, x1 = 20.25f, y1 = 12.5f)
    arcTo(7f, 7f, 0f, isMoreThanHalf = false, isPositiveArc = true, x1 = 11.5f, y1 = 3.75f)
    close()
    sparkle(16.75f, 7.5f, 2.25f)
    sparkle(20.25f, 3.75f, 1.25f)
  }

  /** `circle.hexagongrid.fill` — a project motif. A disc with a hexagon of dots cut out. */
  val CircleHexagonGridFill: ImageVector = filledIcon("CompassionCircleHexagonGridFill", PathFillType.EvenOdd) {
    circle(12f, 12f, 9f)
    circle(12f, 12f, 1.35f)
    // Six dots at r = 4.6, every 60°.
    circle(16.6f, 12f, 1.35f)
    circle(14.3f, 15.98f, 1.35f)
    circle(9.7f, 15.98f, 1.35f)
    circle(7.4f, 12f, 1.35f)
    circle(9.7f, 8.02f, 1.35f)
    circle(14.3f, 8.02f, 1.35f)
  }

  /** `bus.fill` — a project motif. A bus seen head-on: windscreen and headlights cut out, wheels below. */
  val BusFill: ImageVector = filledIcon("CompassionBusFill", PathFillType.EvenOdd) {
    roundedPolygon(
      4.5f, 3.25f, 2.5f,
      19.5f, 3.25f, 2.5f,
      19.5f, 18f, 1f,
      18f, 18f, 0f,
      18f, 20.25f, 0.75f,
      15.5f, 20.25f, 0.75f,
      15.5f, 18f, 0f,
      8.5f, 18f, 0f,
      8.5f, 20.25f, 0.75f,
      6f, 20.25f, 0.75f,
      6f, 18f, 0f,
      4.5f, 18f, 1f,
    )
    roundRect(6.5f, 5.5f, 17.5f, 11.75f, 1f)
    circle(7.75f, 14.75f, 1.1f)
    circle(16.25f, 14.75f, 1.1f)
  }

  /** `heart.text.square.fill` — a project motif. A rounded square with a heart and two lines of text cut out. */
  val HeartTextSquareFill: ImageVector = filledIcon("CompassionHeartTextSquareFill", PathFillType.EvenOdd) {
    roundRect(3.5f, 3.5f, 20.5f, 20.5f, 4.5f)
    heart(cx = 12f, cy = 9f, scale = 0.36f)
    roundRect(7.5f, 13.75f, 16.5f, 15f, 0.625f)
    roundRect(9f, 16.5f, 15f, 17.75f, 0.625f)
  }

  /** `brain.head.profile` — a project motif. A head in profile, facing left, a brain inside. */
  val BrainHeadProfile: ImageVector = lineIcon("CompassionBrainHeadProfile") {
    // Head: front of the neck, chin, mouth, nose, brow, crown, back of the neck.
    moveTo(9.5f, 21f)
    lineTo(9.5f, 17.75f)
    lineTo(7.25f, 17.75f)
    curveTo(6f, 17.75f, 5f, 16.75f, 5f, 15.5f)
    lineTo(5f, 13.25f)
    lineTo(3.9f, 12.75f)
    lineTo(5f, 10f)
    curveTo(5.5f, 6f, 8.4f, 3.25f, 12.25f, 3.25f)
    curveTo(16.6f, 3.25f, 20f, 6.6f, 20f, 10.75f)
    curveTo(20f, 13.6f, 18.6f, 16.1f, 16.5f, 17.5f)
    lineTo(16.5f, 21f)
    // Brain: five uneven lobes, and the central fold.
    moveTo(9.75f, 14f)
    curveTo(8.3f, 14f, 7.6f, 12.4f, 8.5f, 11.4f)
    curveTo(7.7f, 10f, 8.6f, 8.3f, 10.2f, 8.45f)
    curveTo(10.7f, 6.9f, 12.8f, 6.5f, 13.8f, 7.7f)
    curveTo(15.4f, 7.2f, 17f, 8.7f, 16.4f, 10.3f)
    curveTo(17.5f, 11.3f, 17f, 13.5f, 15.4f, 13.6f)
    curveTo(14.6f, 14.6f, 12.9f, 14.7f, 12.2f, 13.9f)
    curveTo(11.5f, 14.3f, 10.6f, 14.3f, 9.75f, 14f)
    close()
    moveTo(12.3f, 7.4f)
    curveTo(11.6f, 9f, 13.3f, 10.4f, 12.2f, 13.9f)
  }

  /** `paintbrush.fill` — a project motif. A brush on the diagonal, handle up-right, bristles down-left. */
  val PaintbrushFill: ImageVector = filledIcon("CompassionPaintbrushFill") {
    capsule(19.75f, 4.25f, 13.1f, 10.9f, 1.1f)
    moveTo(10.75f, 11.25f)
    lineTo(12.75f, 13.25f)
    curveTo(12.75f, 16.5f, 10.5f, 19.75f, 4f, 20f)
    curveTo(4.25f, 13.5f, 7.5f, 11.25f, 10.75f, 11.25f)
    close()
  }

  /** `books.vertical.fill` — a project motif. Two books standing and one leaning, spine bands cut out. */
  val BooksVerticalFill: ImageVector = filledIcon("CompassionBooksVerticalFill", PathFillType.EvenOdd) {
    book(left = 3.5f, bottom = 20f, width = 4f, height = 16f)
    book(left = 8.5f, bottom = 20f, width = 4f, height = 13.5f)
    book(left = 14.1f, bottom = 19.1f, width = 3.5f, height = 12.5f, tiltDegrees = 15f)
  }

  /** `rosette` — a project motif. A scalloped medal on two notched ribbons. */
  val Rosette: ImageVector = lineIcon("CompassionRosette") {
    scallopedCircle(12f, 9f, 5.25f, bumps = 10, swell = 1.4f)
    circle(12f, 9f, 2.25f)
    // Ribbons, each ending in a notch.
    moveTo(8.75f, 13.25f)
    lineTo(7f, 20f)
    lineTo(9.25f, 19.25f)
    lineTo(10.5f, 21f)
    lineTo(11.25f, 14.5f)
    moveTo(15.25f, 13.25f)
    lineTo(17f, 20f)
    lineTo(14.75f, 19.25f)
    lineTo(13.5f, 21f)
    lineTo(12.75f, 14.5f)
  }

  /** `tree.fill` — a project motif. A round, cloud-like canopy on a trunk. */
  val TreeFill: ImageVector = filledIcon("CompassionTreeFill") {
    // Overlapping discs of one winding, so they union into one canopy.
    circle(12f, 7.5f, 4.5f)
    circle(8f, 11f, 3.75f)
    circle(16f, 11f, 3.75f)
    circle(12f, 12f, 4f)
    roundRect(10.9f, 13f, 13.1f, 20.75f, 1.1f)
  }

  /** `drop.fill` — a project motif. A water drop. */
  val DropFill: ImageVector = filledIcon("CompassionDropFill") {
    moveTo(12f, 3f)
    curveTo(12f, 3f, 5.5f, 10.25f, 5.5f, 14.5f)
    curveTo(5.5f, 18.1f, 8.4f, 21f, 12f, 21f)
    curveTo(15.6f, 21f, 18.5f, 18.1f, 18.5f, 14.5f)
    curveTo(18.5f, 10.25f, 12f, 3f, 12f, 3f)
    close()
  }

  /** `pawprint.fill` — a project motif. A pad and four toes. */
  val PawprintFill: ImageVector = filledIcon("CompassionPawprintFill") {
    moveTo(12f, 12f)
    curveTo(15f, 12f, 17.75f, 15.25f, 17.75f, 17.5f)
    curveTo(17.75f, 19.1f, 16.5f, 20f, 15f, 20f)
    curveTo(13.9f, 20f, 13.1f, 19.4f, 12f, 19.4f)
    curveTo(10.9f, 19.4f, 10.1f, 20f, 9f, 20f)
    curveTo(7.5f, 20f, 6.25f, 19.1f, 6.25f, 17.5f)
    curveTo(6.25f, 15.25f, 9f, 12f, 12f, 12f)
    close()
    ellipse(9.4f, 6.75f, 1.8f, 2.3f)
    ellipse(14.6f, 6.75f, 1.8f, 2.3f)
    ellipse(5.4f, 10.75f, 1.65f, 2.1f)
    ellipse(18.6f, 10.75f, 1.65f, 2.1f)
  }

  /** `figure.2.arms.open` — a project motif. Two figures side by side, arms raised open. */
  val FigureTwoArmsOpen: ImageVector = filledIcon("CompassionFigureTwoArmsOpen") {
    figureArmsOpen(7.5f)
    figureArmsOpen(16.5f)
  }

  /** `fork.knife` — a project motif. A fork beside a knife. */
  val ForkKnife: ImageVector = lineIcon("CompassionForkKnife") {
    // Fork: outer tines and the bowl, then the middle tine running down as the handle.
    moveTo(5.5f, 3.5f)
    lineTo(5.5f, 8f)
    curveTo(5.5f, 9.4f, 6.4f, 10.5f, 7.5f, 10.5f)
    curveTo(8.6f, 10.5f, 9.5f, 9.4f, 9.5f, 8f)
    lineTo(9.5f, 3.5f)
    moveTo(7.5f, 3.5f)
    lineTo(7.5f, 20.5f)
    // Knife: a straight spine with the blade bellying out to the right.
    moveTo(16.5f, 20.5f)
    lineTo(16.5f, 3.5f)
    curveTo(18.5f, 4.5f, 19f, 8f, 19f, 11f)
    lineTo(19f, 12.25f)
    curveTo(19f, 12.9f, 18.5f, 13.25f, 17.75f, 13.25f)
    lineTo(16.5f, 13.25f)
  }

  /** `house.lodge.fill` — a project motif. A cabin: wide eaves, a chimney, its door notched out. */
  val HouseLodgeFill: ImageVector = filledIcon("CompassionHouseLodgeFill") {
    roundedPolygon(
      12f, 4f, 1f,
      15.5f, 6.92f, 0f,
      15.5f, 4.75f, 0.5f,
      17.5f, 4.75f, 0.5f,
      17.5f, 8.58f, 0f,
      21f, 11.5f, 1f,
      18.5f, 11.5f, 0f,
      18.5f, 20f, 1f,
      14f, 20f, 0.4f,
      14f, 15f, 1f,
      10f, 15f, 1f,
      10f, 20f, 0.4f,
      5.5f, 20f, 1f,
      5.5f, 11.5f, 0f,
      3f, 11.5f, 1f,
    )
  }

  /** `graduationcap.fill` — a project motif. A mortarboard over its cap, the tassel hanging right. */
  val GraduationcapFill: ImageVector = filledIcon("CompassionGraduationcapFill") {
    // Board.
    roundedPolygon(
      12f, 5.5f, 1.25f,
      21f, 9.75f, 1.25f,
      12f, 14f, 1.25f,
      3f, 9.75f, 1.25f,
    )
    // Cap, its top running parallel to the board a unit below.
    roundedPolygon(
      6.5f, 12.5f, 0.5f,
      12f, 15.1f, 0.6f,
      17.5f, 12.5f, 0.5f,
      17.5f, 18f, 2f,
      6.5f, 18f, 2f,
    )
    // Tassel.
    capsule(19.75f, 10.75f, 19.75f, 16f, 0.6f)
    ellipse(19.75f, 16.75f, 1f, 1.4f)
  }

  // MARK: - Partner marks

  /** `hands.and.sparkles.fill` — a partner mark. Two cupped hands with sparkles rising above them. */
  val HandsAndSparklesFill: ImageVector = filledIcon("CompassionHandsAndSparklesFill") {
    // Left hand: fingertips, inner palm curving to the seam, wrist, outer edge.
    moveTo(3.5f, 12.25f)
    curveTo(3.5f, 11.55f, 4.05f, 11f, 4.75f, 11f)
    curveTo(5.45f, 11f, 6f, 11.55f, 6f, 12.25f)
    lineTo(6f, 13f)
    curveTo(6f, 14.8f, 8.2f, 16.25f, 11.25f, 16.25f)
    lineTo(11.25f, 20.5f)
    lineTo(8.5f, 20.5f)
    curveTo(5.25f, 19.25f, 3.5f, 16.5f, 3.5f, 13.5f)
    close()
    // Right hand, mirrored.
    moveTo(20.5f, 12.25f)
    curveTo(20.5f, 11.55f, 19.95f, 11f, 19.25f, 11f)
    curveTo(18.55f, 11f, 18f, 11.55f, 18f, 12.25f)
    lineTo(18f, 13f)
    curveTo(18f, 14.8f, 15.8f, 16.25f, 12.75f, 16.25f)
    lineTo(12.75f, 20.5f)
    lineTo(15.5f, 20.5f)
    curveTo(18.75f, 19.25f, 20.5f, 16.5f, 20.5f, 13.5f)
    close()
    sparkle(12f, 9.5f, 3.5f)
    sparkle(17f, 5.25f, 1.75f)
    sparkle(7.25f, 5.75f, 1.25f)
  }

  /** `stethoscope` — a partner mark. Earpieces joined in a U, the tube looping round to the chest piece. */
  val Stethoscope: ImageVector = lineIcon("CompassionStethoscope") {
    moveTo(6.75f, 3.5f)
    lineTo(5.5f, 3.5f)
    lineTo(5.5f, 8.5f)
    curveTo(5.5f, 11f, 6.85f, 13f, 8.5f, 13f)
    curveTo(10.15f, 13f, 11.5f, 11f, 11.5f, 8.5f)
    lineTo(11.5f, 3.5f)
    lineTo(10.25f, 3.5f)
    moveTo(8.5f, 13f)
    lineTo(8.5f, 16.25f)
    curveTo(8.5f, 19f, 10.5f, 20.5f, 12.75f, 20.5f)
    curveTo(15.25f, 20.5f, 16.75f, 19f, 16.75f, 16.5f)
    lineTo(16.75f, 14.25f)
    circle(16.75f, 12f, 2.25f)
  }

  /** `person.3.fill` — a partner mark. One bust in front, two tucked behind either side. */
  val PersonThreeFill: ImageVector = filledIcon("CompassionPersonThreeFill") {
    circle(12f, 8.25f, 2.9f)
    shoulders(cx = 12f, rx = 5.25f, top = 12.75f, bottom = 20f)
    circle(5.5f, 7.5f, 2.2f)
    circle(18.5f, 7.5f, 2.2f)
    // The back shoulders stop 1.4 short of the front ones, which sets them behind.
    moveTo(16.43f, 13.23f)
    curveTo(16.92f, 11.98f, 17.69f, 11.25f, 18.5f, 11.25f)
    curveTo(19.94f, 11.25f, 21.1f, 13.49f, 21.1f, 16.25f)
    quadTo(21.1f, 17.25f, 20.1f, 17.25f)
    lineTo(18.51f, 17.25f)
    curveTo(18.22f, 15.7f, 17.49f, 14.29f, 16.43f, 13.23f)
    close()
    moveTo(7.57f, 13.23f)
    curveTo(7.08f, 11.98f, 6.31f, 11.25f, 5.5f, 11.25f)
    curveTo(4.06f, 11.25f, 2.9f, 13.49f, 2.9f, 16.25f)
    quadTo(2.9f, 17.25f, 3.9f, 17.25f)
    lineTo(5.49f, 17.25f)
    curveTo(5.78f, 15.7f, 6.51f, 14.29f, 7.57f, 13.23f)
    close()
  }

  // MARK: - UI glyphs

  /** `chart.pie.fill` — a category's share of the portfolio. A pie with its top-right wedge drawn out. */
  val ChartPieFill: ImageVector = filledIcon("CompassionChartPieFill") {
    moveTo(11.25f, 12.75f)
    lineTo(11.25f, 5f)
    arcTo(7.75f, 7.75f, 0f, isMoreThanHalf = true, isPositiveArc = false, x1 = 19f, y1 = 12.75f)
    close()
    moveTo(12.5f, 11.5f)
    lineTo(12.5f, 3.75f)
    arcTo(7.75f, 7.75f, 0f, isMoreThanHalf = false, isPositiveArc = true, x1 = 20.25f, y1 = 11.5f)
    close()
  }

  /** `target` — a project's goal on its card. Three concentric rings. */
  val Target: ImageVector = lineIcon("CompassionTarget") {
    circle(12f, 12f, 8.75f)
    circle(12f, 12f, 5.5f)
    circle(12f, 12f, 2.25f)
  }

  /** `person.2.fill` — supporters on a category and in the impact pebbles. One bust in front, one behind. */
  val PersonTwoFill: ImageVector = filledIcon("CompassionPersonTwoFill") {
    circle(9f, 8.25f, 3.25f)
    shoulders(cx = 9f, rx = 6f, top = 13.25f, bottom = 20f)
    circle(16.25f, 6.75f, 2.6f)
    // The back shoulders stop 1.4 short of the front ones, which sets them behind.
    moveTo(12.87f, 12.87f)
    curveTo(13.72f, 11.68f, 14.96f, 11f, 16.25f, 11f)
    curveTo(18.74f, 11f, 20.75f, 13.46f, 20.75f, 16.5f)
    quadTo(20.75f, 17.75f, 19.5f, 17.75f)
    lineTo(16.32f, 17.75f)
    curveTo(16f, 15.73f, 14.74f, 13.94f, 12.87f, 12.87f)
    close()
  }

  /** `mappin.and.ellipse` — a field report's location. A pin standing on the ground. */
  val MappinAndEllipse: ImageVector = lineIcon("CompassionMappinAndEllipse") {
    circle(12f, 7.75f, 4.25f)
    moveTo(12f, 12f)
    lineTo(12f, 17.25f)
    ellipse(12f, 17.25f, 7.5f, 3f)
  }

  /** `calendar` — a partner's founding year. A page with its header and two binder rings. */
  val Calendar: ImageVector = lineIcon("CompassionCalendar") {
    roundRect(3.5f, 5f, 20.5f, 20.5f, 2.5f)
    moveTo(3.5f, 9.5f)
    lineTo(20.5f, 9.5f)
    moveTo(8f, 3.25f)
    lineTo(8f, 6.5f)
    moveTo(16f, 3.25f)
    lineTo(16f, 6.5f)
  }

  /** `link` — a partner's website. Two chain links interlocked on the diagonal. */
  val Link: ImageVector = lineIcon("CompassionLink") {
    capsule(7.31f, 16.69f, 11.19f, 12.81f, 3f)
    capsule(12.81f, 11.19f, 16.69f, 7.31f, 3f)
  }

  /** `delete.left` — the donate keypad's backspace. A left-pointing tag with an × inside. */
  val DeleteLeft: ImageVector = lineIcon("CompassionDeleteLeft") {
    roundedPolygon(
      3f, 12f, 1f,
      8f, 5.5f, 1.5f,
      20.75f, 5.5f, 2.5f,
      20.75f, 18.5f, 2.5f,
      8f, 18.5f, 1.5f,
    )
    moveTo(11f, 9.75f)
    lineTo(15.5f, 14.25f)
    moveTo(15.5f, 9.75f)
    lineTo(11f, 14.25f)
  }

  /** `heart` — the unfilled heart on the send-a-heart bar and the donate picker. The same outline as [HeartFill]. */
  val HeartOutline: ImageVector = lineIcon("CompassionHeartOutline") { heart() }

  // MARK: - Shapes

  private fun PathBuilder.ellipse(cx: Float, cy: Float, rx: Float, ry: Float) {
    val kx = rx * CIRCLE_K
    val ky = ry * CIRCLE_K
    moveTo(cx, cy - ry)
    curveTo(cx + kx, cy - ry, cx + rx, cy - ky, cx + rx, cy)
    curveTo(cx + rx, cy + ky, cx + kx, cy + ry, cx, cy + ry)
    curveTo(cx - kx, cy + ry, cx - rx, cy + ky, cx - rx, cy)
    curveTo(cx - rx, cy - ky, cx - kx, cy - ry, cx, cy - ry)
    close()
  }

  private fun PathBuilder.circle(cx: Float, cy: Float, r: Float) = ellipse(cx, cy, r, r)

  private fun PathBuilder.roundRect(left: Float, top: Float, right: Float, bottom: Float, radius: Float) =
    roundedPolygon(
      left, top, radius,
      right, top, radius,
      right, bottom, radius,
      left, bottom, radius,
    )

  /**
   * A closed polygon through `x, y, cornerRadius` triples, each corner eased by
   * a quadratic; a radius of 0 keeps that corner sharp. List the points
   * clockwise so overlapping solids union under the non-zero rule.
   */
  private fun PathBuilder.roundedPolygon(vararg xyr: Float) {
    val n = xyr.size / 3
    for (i in 0 until n) {
      val x = xyr[i * 3]
      val y = xyr[i * 3 + 1]
      val r = xyr[i * 3 + 2]
      val p = (i + n - 1) % n
      val q = (i + 1) % n
      val px = xyr[p * 3]
      val py = xyr[p * 3 + 1]
      val qx = xyr[q * 3]
      val qy = xyr[q * 3 + 1]
      val inLength = hypot(x - px, y - py)
      val outLength = hypot(qx - x, qy - y)
      val rIn = min(r, inLength / 2f)
      val rOut = min(r, outLength / 2f)
      val ax = x + (px - x) / inLength * rIn
      val ay = y + (py - y) / inLength * rIn
      if (i == 0) moveTo(ax, ay) else lineTo(ax, ay)
      if (r > 0f) quadTo(x, y, x + (qx - x) / outLength * rOut, y + (qy - y) / outLength * rOut)
    }
    close()
  }

  /** A stadium between two cap centres, clockwise. */
  private fun PathBuilder.capsule(fromX: Float, fromY: Float, toX: Float, toY: Float, halfWidth: Float) {
    val length = hypot(toX - fromX, toY - fromY)
    val nx = (toY - fromY) / length * halfWidth
    val ny = -(toX - fromX) / length * halfWidth
    moveTo(fromX + nx, fromY + ny)
    lineTo(toX + nx, toY + ny)
    arcTo(halfWidth, halfWidth, 0f, isMoreThanHalf = false, isPositiveArc = true, x1 = toX - nx, y1 = toY - ny)
    lineTo(fromX - nx, fromY - ny)
    arcTo(halfWidth, halfWidth, 0f, isMoreThanHalf = false, isPositiveArc = true, x1 = fromX + nx, y1 = fromY + ny)
    close()
  }

  /** A four-point sparkle, the same curve as `ProfileIcons.Sparkles`. */
  private fun PathBuilder.sparkle(cx: Float, cy: Float, r: Float) {
    val a = r * 0.086f
    val b = r * 0.371f
    moveTo(cx, cy - r)
    curveTo(cx + a, cy - b, cx + b, cy - a, cx + r, cy)
    curveTo(cx + b, cy + a, cx + a, cy + b, cx, cy + r)
    curveTo(cx - a, cy + b, cx - b, cy + a, cx - r, cy)
    curveTo(cx - b, cy - a, cx - a, cy - b, cx, cy - r)
    close()
  }

  /**
   * The DEEP heart (x 3.75…20.25, y 3.75…20 at full size, like `DeepIcons.Heart`
   * and `HeartShape`), centred on [cx], [cy] and scaled by [scale].
   */
  private fun PathBuilder.heart(cx: Float = 12f, cy: Float = 11.875f, scale: Float = 1f) {
    fun x(v: Float) = cx + (v - 12f) * scale
    fun y(v: Float) = cy + (v - 11.875f) * scale
    moveTo(x(12f), y(20f))
    curveTo(x(12f), y(20f), x(3.75f), y(14.5f), x(3.75f), y(9f))
    curveTo(x(3.75f), y(6.1f), x(6.1f), y(3.75f), x(9f), y(3.75f))
    curveTo(x(10.7f), y(3.75f), x(12f), y(4.7f), x(12f), y(6.3f))
    curveTo(x(12f), y(4.7f), x(13.3f), y(3.75f), x(15f), y(3.75f))
    curveTo(x(17.9f), y(3.75f), x(20.25f), y(6.1f), x(20.25f), y(9f))
    curveTo(x(20.25f), y(14.5f), x(12f), y(20f), x(12f), y(20f))
    close()
  }

  /** A circle whose edge swells into [bumps] soft scallops, [swell] beyond [r] at each control point. */
  private fun PathBuilder.scallopedCircle(cx: Float, cy: Float, r: Float, bumps: Int, swell: Float) {
    val step = 2.0 * PI / bumps
    val start = -PI / 2.0
    moveTo(cx, cy - r)
    for (i in 0 until bumps) {
      val mid = start + step * (i + 0.5)
      val end = start + step * (i + 1)
      quadTo(
        cx + (r + swell) * cos(mid).toFloat(),
        cy + (r + swell) * sin(mid).toFloat(),
        cx + r * cos(end).toFloat(),
        cy + r * sin(end).toFloat(),
      )
    }
    close()
  }

  /**
   * One book for [BooksVerticalFill]: a spine standing on its bottom-left corner
   * ([left], [bottom]), leaning right by [tiltDegrees], with two bands cut out
   * (the icon fills even-odd).
   */
  private fun PathBuilder.book(left: Float, bottom: Float, width: Float, height: Float, tiltDegrees: Float = 0f) {
    val t = tiltDegrees / 180f * PI.toFloat()
    // Across the spine, and up it.
    val acrossX = cos(t)
    val acrossY = sin(t)
    val upX = sin(t)
    val upY = -cos(t)
    fun quad(w0: Float, h0: Float, w1: Float, h1: Float, r: Float) = roundedPolygon(
      left + w0 * acrossX + h1 * upX, bottom + w0 * acrossY + h1 * upY, r,
      left + w1 * acrossX + h1 * upX, bottom + w1 * acrossY + h1 * upY, r,
      left + w1 * acrossX + h0 * upX, bottom + w1 * acrossY + h0 * upY, r,
      left + w0 * acrossX + h0 * upX, bottom + w0 * acrossY + h0 * upY, r,
    )
    quad(0f, 0f, width, height, 0.9f)
    quad(0.75f, 2f, width - 0.75f, 3f, 0.4f)
    quad(0.75f, height - 3f, width - 0.75f, height - 2f, 0.4f)
  }

  /** A bust's shoulders: a dome [rx] either side of [cx], from [top] down to a flat [bottom]. */
  private fun PathBuilder.shoulders(cx: Float, rx: Float, top: Float, bottom: Float) {
    val corner = 1.25f
    val base = bottom - corner
    val ry = base - top
    moveTo(cx - rx, base)
    curveTo(cx - rx, base - ry * CIRCLE_K, cx - rx * CIRCLE_K, top, cx, top)
    curveTo(cx + rx * CIRCLE_K, top, cx + rx, base - ry * CIRCLE_K, cx + rx, base)
    quadTo(cx + rx, bottom, cx + rx - corner, bottom)
    lineTo(cx - rx + corner, bottom)
    quadTo(cx - rx, bottom, cx - rx, base)
    close()
  }

  /** One figure for [FigureTwoArmsOpen], centred on [cx]: head, torso, legs, and arms raised outward. */
  private fun PathBuilder.figureArmsOpen(cx: Float) {
    circle(cx, 5.25f, 2f)
    capsule(cx, 10f, cx, 14.25f, 1.5f)
    capsule(cx - 0.5f, 14f, cx - 1.4f, 20f, 1f)
    capsule(cx + 0.5f, 14f, cx + 1.4f, 20f, 1f)
    capsule(cx - 0.5f, 10.5f, cx - 3.25f, 7.75f, 0.85f)
    capsule(cx + 0.5f, 10.5f, cx + 3.25f, 7.75f, 0.85f)
  }

  // MARK: - Builders

  private fun lineIcon(name: String, path: PathBuilder.() -> Unit): ImageVector =
    ImageVector.Builder(
      name = name,
      defaultWidth = 24.dp,
      defaultHeight = 24.dp,
      viewportWidth = 24f,
      viewportHeight = 24f,
    ).addPath(
      pathData = PathData(path),
      fill = null,
      stroke = SolidColor(Color.Black), // replaced by the Icon tint at the call site
      strokeLineWidth = 1.5f,
      strokeLineCap = StrokeCap.Round,
      strokeLineJoin = StrokeJoin.Round,
    ).build()

  private fun filledIcon(
    name: String,
    fillType: PathFillType = PathFillType.NonZero,
    path: PathBuilder.() -> Unit,
  ): ImageVector =
    ImageVector.Builder(
      name = name,
      defaultWidth = 24.dp,
      defaultHeight = 24.dp,
      viewportWidth = 24f,
      viewportHeight = 24f,
    ).addPath(
      pathData = PathData(path),
      pathFillType = fillType,
      fill = SolidColor(Color.Black), // replaced by the Icon tint at the call site
    ).build()
}

@Preview(showBackground = true, name = "Compassion icons")
@Composable
private fun CompassionIconsPreview() {
  val glyphs = listOf(
    CompassionIcons.BirdFill,
    CompassionIcons.CrossFill,
    CompassionIcons.BookFill,
    CompassionIcons.LeafFill,
    CompassionIcons.HouseFill,
    CompassionIcons.HeartFill,
    CompassionIcons.FlameFill,
    CompassionIcons.MoonStarsFill,
    CompassionIcons.CircleHexagonGridFill,
    CompassionIcons.BusFill,
    CompassionIcons.HeartTextSquareFill,
    CompassionIcons.BrainHeadProfile,
    CompassionIcons.PaintbrushFill,
    CompassionIcons.BooksVerticalFill,
    CompassionIcons.Rosette,
    CompassionIcons.TreeFill,
    CompassionIcons.DropFill,
    CompassionIcons.PawprintFill,
    CompassionIcons.FigureTwoArmsOpen,
    CompassionIcons.ForkKnife,
    CompassionIcons.HouseLodgeFill,
    CompassionIcons.GraduationcapFill,
    CompassionIcons.HandsAndSparklesFill,
    CompassionIcons.Stethoscope,
    CompassionIcons.PersonThreeFill,
    CompassionIcons.ChartPieFill,
    CompassionIcons.Target,
    CompassionIcons.PersonTwoFill,
    CompassionIcons.MappinAndEllipse,
    CompassionIcons.Calendar,
    CompassionIcons.Link,
    CompassionIcons.DeleteLeft,
    CompassionIcons.HeartOutline,
  )
  Column(
    Modifier.fillMaxSize().background(Color.moonCream).padding(Dp.edge),
    verticalArrangement = Arrangement.spacedBy(16.dp),
  ) {
    glyphs.chunked(6).forEach { row ->
      Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
        row.forEach { Icon(it, contentDescription = null, tint = Color.deepPlum, modifier = Modifier.size(32.dp)) }
      }
    }
  }
}
