package io.appbeyond.freelance.deep.feature.compassion.components

import android.graphics.Bitmap
import android.graphics.BlurMaskFilter
import android.graphics.Paint
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.asAndroidPath
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.rotateRad
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.core.graphics.createBitmap
import io.appbeyond.freelance.deep.feature.compassion.model.HeartTone
import io.appbeyond.freelance.deep.feature.compassion.model.RisingHeart
import io.appbeyond.freelance.deep.feature.compassion.model.RisingHeartsField
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.HeartShape
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.blushPowder
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.peachCloud
import kotlin.math.ceil

// MARK: - Constants

/**
 * The lavender seat that keeps the white hearts legible on the pale
 * atmosphere — iOS's layer `shadow(lavenderMist 0.45, radius: 6, y: 2)`.
 */
private const val SHADOW_ALPHA = 0.45f
private val SHADOW_RADIUS = 6.dp
private val SHADOW_OFFSET_Y = 2.dp

/**
 * A bold `heart.fill`'s glyph box per point of font size — HeartBurst's
 * measured 18pt → 20 × 19dp.
 */
private const val GLYPH_WIDTH_PER_POINT = 20f / 18f
private const val GLYPH_HEIGHT_PER_POINT = 19f / 18f

// MARK: - Hearts

/**
 * A gift made visible: hearts lift off one point and drift up through the
 * screen on slow, swaying paths, then fade — floating particles, the motion
 * DESIGN.md asks for, rather than a burst.
 *
 * Ported from Deep/Deep/Features/CompassionPortfolio/Components/RisingHearts.swift;
 * the paths and curves are [RisingHeartsField]'s. The field is rolled once,
 * when this enters composition, so no two gifts rise the same way. It plays a
 * single time on the frame clock; once the last heart has faded the clock
 * stops and nothing is drawn, so it can stay composed under whatever comes
 * next without costing a frame. Callers skip it under reduced motion.
 *
 * Each heart's lavender seat is a blurred alpha mask baked once per heart
 * (iOS's `addFilter(.shadow)`; `Modifier.dropShadow` can't follow a canvas
 * transform), all of them drawn beneath all of the hearts, as iOS's layer
 * shadow is.
 *
 * @param count how many hearts — [RisingHeartsField.count] for the gift.
 * @param origin where the hearts lift off, in px in this composable's space.
 */
@Composable
fun RisingHearts(count: Int, origin: Offset, modifier: Modifier = Modifier) {
  val hearts = remember(count) { RisingHeartsField.roll(count) }
  var elapsed by remember { mutableDoubleStateOf(0.0) }
  var settled by remember { mutableStateOf(false) }

  LaunchedEffect(hearts) {
    val duration = RisingHeartsField.duration(hearts)
    val start = withFrameNanos { it }
    while (elapsed <= duration) {
      elapsed = (withFrameNanos { it } - start) / 1e9
    }
    settled = true
  }

  Spacer(
    modifier
      .fillMaxSize()
      .clearAndSetSemantics {}
      .drawWithCache {
        val sprites = hearts.map { HeartSprite.bake(it, this, layoutDirection) }
        val seat = ColorFilter.tint(Color.lavenderMist)
        onDrawBehind {
          if (settled) return@onDrawBehind
          val poses = hearts.map { RisingHeartsField.pose(it, elapsed) }
          // Every seat first, then every heart: one shadow under the field.
          sprites.forEachIndexed { index, sprite ->
            val pose = poses[index] ?: return@forEachIndexed
            val bloom = (pose.size / hearts[index].size).toFloat()
            place(origin, pose.x, pose.y + SHADOW_OFFSET_Y.value, pose.rotation, bloom) {
              drawImage(
                image = sprite.seat,
                topLeft = sprite.seatTopLeft,
                alpha = SHADOW_ALPHA * pose.opacity.toFloat(),
                colorFilter = seat,
              )
            }
          }
          sprites.forEachIndexed { index, sprite ->
            val pose = poses[index] ?: return@forEachIndexed
            val bloom = (pose.size / hearts[index].size).toFloat()
            place(origin, pose.x, pose.y, pose.rotation, bloom) {
              drawPath(sprite.path, color = hearts[index].tone.color, alpha = pose.opacity.toFloat())
            }
          }
        }
      },
  )
}

/** Moves the canvas to a heart's centre, turned and bloomed about it. */
private inline fun DrawScope.place(
  origin: Offset,
  x: Double,
  y: Double,
  rotation: Double,
  bloom: Float,
  draw: DrawScope.() -> Unit,
) {
  translate(origin.x + x.dp.toPx(), origin.y + y.dp.toPx()) {
    rotateRad(rotation.toFloat(), pivot = Offset.Zero) {
      scale(bloom, bloom, pivot = Offset.Zero) { draw() }
    }
  }
}

private val HeartTone.color: Color
  get() = when (this) {
    HeartTone.MoonCream -> Color.moonCream
    HeartTone.BlushPowder -> Color.blushPowder
    HeartTone.PeachCloud -> Color.peachCloud
  }

/**
 * One heart at its full size, centred on the origin: its outline, and its
 * seat — the outline blurred into an alpha mask with room for the fade.
 */
private class HeartSprite(val path: Path, val seat: ImageBitmap, val seatTopLeft: Offset) {
  companion object {
    fun bake(heart: RisingHeart, density: Density, layoutDirection: LayoutDirection): HeartSprite {
      val size = with(density) { heart.size.dp.toPx() }
      val glyph = Size(size * GLYPH_WIDTH_PER_POINT, size * GLYPH_HEIGHT_PER_POINT)
      val outline = HeartShape.createOutline(glyph, layoutDirection, density) as Outline.Generic
      val path = Path().apply {
        addPath(outline.path, Offset(-glyph.width / 2f, -glyph.height / 2f))
      }

      val radius = with(density) { SHADOW_RADIUS.toPx() }
      val margin = ceil(radius * 2f)
      val mask = createBitmap(
        ceil(glyph.width + margin * 2f).toInt(),
        ceil(glyph.height + margin * 2f).toInt(),
        Bitmap.Config.ALPHA_8,
      )
      android.graphics.Canvas(mask).apply {
        translate(margin, margin)
        drawPath(
          outline.path.asAndroidPath(),
          Paint(Paint.ANTI_ALIAS_FLAG).apply { maskFilter = BlurMaskFilter(radius, BlurMaskFilter.Blur.NORMAL) },
        )
      }
      return HeartSprite(
        path = path,
        seat = mask.asImageBitmap(),
        seatTopLeft = Offset(-glyph.width / 2f - margin, -glyph.height / 2f - margin),
      )
    }
  }
}

// MARK: - Previews

@Preview(showBackground = true, name = "Rising hearts", heightDp = 800)
@Composable
private fun RisingHeartsPreview() {
  var gift by remember { mutableIntStateOf(1) }
  var amount by remember { mutableIntStateOf(10) }
  BoxWithConstraints(Modifier.fillMaxSize().background(Color.moonCream)) {
    AtmosphereBackground(animated = false)
    val origin = with(LocalDensity.current) {
      Offset(maxWidth.toPx() / 2f, maxHeight.toPx() * 0.8f)
    }
    key(gift) {
      RisingHearts(count = RisingHeartsField.count(amount), origin = origin)
    }
    Row(
      Modifier.align(Alignment.BottomCenter).padding(bottom = 48.dp),
      horizontalArrangement = Arrangement.spacedBy(24.dp),
    ) {
      listOf(1, 10, 100).forEach { value ->
        Box(
          Modifier
            .clickable {
              amount = value
              gift += 1
            }
            .padding(8.dp),
        ) {
          Text("Give $value", style = DeepType.bodyMedium, color = Color.deepPlum)
        }
      }
    }
  }
}
