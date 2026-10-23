package io.appbeyond.freelance.deep.shared.components

import android.os.Build
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.State
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.BlurEffect
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Paint
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.TileMode
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.layer.drawLayer
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.input.nestedscroll.NestedScrollConnection
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.toSize
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.shared.header.HeaderCollapse
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.frostedCard
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.rhythm
import io.appbeyond.freelance.deep.theme.softLilac
import kotlin.math.ceil
import kotlin.math.min

// MARK: - Constants

/** Height of the compact bar below the status bar — iOS's `compactBarHeight`. */
private val COMPACT_BAR_HEIGHT = 52.dp

/** The titles' resting drop below the status bar — iOS's `topInset + 6`. */
private val TITLE_TOP = 6.dp

/**
 * Where the subtitle sits below the status bar — iOS's `topInset + 40`, which
 * is the wordmark's line box (6 + 34) so the caption lands right under it.
 */
private val SUBTITLE_TOP = 40.dp

/** The large title's legibility shadow over the video — iOS's `radius: 8, y: 2`. */
private val TITLE_SHADOW_RADIUS = 8.dp
private val TITLE_SHADOW_Y = 2.dp

/** The subtitle's gentler shadow — iOS's `radius: 6, y: 1`. */
private val SUBTITLE_SHADOW_RADIUS = 6.dp
private val SUBTITLE_SHADOW_Y = 1.dp

/** The subtitle's white, eased just off pure — iOS's `.white.opacity(0.92)`. */
private const val SUBTITLE_ALPHA = 0.92f

/** The compact title may shrink to this share of its size before truncating. */
private const val COMPACT_MIN_SCALE = 0.8f

/** Past this progress the header has settled onto the bar (plum treatment). */
private const val OVER_HERO_UNTIL = 0.5f

/**
 * Blur strength at the bar's top edge. iOS asks `variableBlur` for an
 * `inputRadius` of 20pt, which Core Image treats as the gaussian's sigma.
 * Android's `RenderEffect` takes a *radius* and converts it internally
 * (sigma ≈ 0.577 · radius + 0.5), so 34dp is what lands on the same sigma.
 */
private val BLUR_RADIUS = 34.dp

/**
 * Peak opacity of the pre-31 stand-in wash at the bar's top edge. Strong enough
 * that a card passing beneath reads as frosted behind the plum title, not so
 * strong it turns into a slab.
 */
private const val SCRIM_ALPHA = 0.88f

// MARK: - Header state

/**
 * True while the header still floats over the dark video (accessories should
 * use their light, over-hero treatment); false once it has settled onto the
 * blurred bar (use the plum treatment). Lets a trailing accessory — e.g. a
 * heart-balance chip — flip in step with the title without the header needing
 * to know what the accessory is.
 *
 * The twin of iOS's `@Entry var headerOverDarkHero`. Provided to both the
 * trailing slot and the content, as the SwiftUI environment is.
 */
val LocalHeaderOverDarkHero = compositionLocalOf { true }

// MARK: - Header

/**
 * A home-screen header that floats over a [StretchyHero] and collapses like the
 * iOS large-title nav bar. At rest the title sits large in the top-left over
 * the video (white, legible against the footage); as the list scrolls the
 * large title rolls up and clips out while a compact serif-italic title rises
 * into a progressively blurred bar from just below — a directional roll, not a
 * cross-dissolve. The title eases from white to deepPlum as it lands.
 *
 * Ported from Deep/Deep/Shared/Components/CollapsibleHomeHeader.swift. The
 * numbers — the 110dp collapse, the 40dp roll, every fade curve — come from
 * [HeaderCollapse] in :core:model, so both platforms roll in step.
 *
 * **A container, not an overlay.** iOS gets its progressive blur from a
 * backdrop filter that reads whatever lies behind it. Compose has no backdrop
 * read, so the blur is applied to the scroll content itself: this composable
 * wraps [content], records it once per frame, and draws the top band again
 * blurred. That is also why the atmosphere is safe — keep
 * [AtmosphereBackground] *outside* [content], behind this composable, and the
 * blur can never reach its orbs (blurring those turns them into hard discs).
 *
 * Below API 31 `RenderEffect` does not exist, so the band is a moonCream wash
 * instead — painted source-atop, so it frosts the content passing under the bar
 * and leaves the atmosphere behind it untouched.
 *
 * Fills the space it is given. The hero is expected to bleed under the status
 * bar (the app is edge-to-edge); the header reads the status-bar inset itself.
 *
 * Usage, the Compose shape of iOS's `.collapsibleHomeHeader(title:subtitle:)`:
 *
 * ```
 * Box(Modifier.fillMaxSize().background(Color.moonCream)) {
 *   AtmosphereBackground()
 *   CollapsibleHomeHeader(title = "Home", subtitle = "…", listState = listState) {
 *     LazyColumn(state = listState, …) { item { StretchyHero(…) } … }
 *   }
 * }
 * ```
 *
 * @param title the screen's name — large over the hero, compact on the bar.
 * @param listState the state of the [content]'s list; its scroll drives the
 *   collapse.
 * @param subtitle an optional line under the large title. It clears first, so
 *   the compact bar shows the name alone.
 * @param trailing an accessory fixed top-right. It does not roll; read
 *   [LocalHeaderOverDarkHero] inside it to flip its treatment with the title.
 * @param content the scrolling screen, led by a [StretchyHero].
 */
@Composable
fun CollapsibleHomeHeader(
  title: String,
  listState: LazyListState,
  modifier: Modifier = Modifier,
  subtitle: String? = null,
  trailing: @Composable () -> Unit = {},
  content: @Composable () -> Unit,
) {
  val density = LocalDensity.current

  // Normalised so 0 is the resting top. Past the first item the hero has long
  // since dissolved, so the header is simply fully collapsed.
  val progress = remember(listState, density) {
    derivedStateOf {
      val scrolled = if (listState.firstVisibleItemIndex > 0) {
        Float.MAX_VALUE
      } else {
        listState.firstVisibleItemScrollOffset / density.density
      }
      HeaderCollapse.progress(scrolled)
    }
  }
  val overDarkHero by remember { derivedStateOf { progress.value < OVER_HERO_UNTIL } }

  val topInset = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
  val barHeight = topInset + COMPACT_BAR_HEIGHT

  CompositionLocalProvider(LocalHeaderOverDarkHero provides overDarkHero) {
    Box(modifier) {
      Box(
        Modifier
          .fillMaxSize()
          .headerBackdrop(barHeight) { HeaderCollapse.barMaterialOpacity(progress.value) },
      ) {
        content()
      }

      HeaderBar(
        title = title,
        subtitle = subtitle,
        progress = progress,
        topInset = topInset,
        barHeight = barHeight,
        trailing = trailing,
      )
    }
  }
}

/**
 * The floating layer: the rolling titles (the only clipped region, so the large
 * title disappears under the status bar instead of fading in place), the
 * subtitle outside the clip, and the fixed trailing accessory.
 *
 * Nothing here consumes touches except whatever [trailing] brings, so drags
 * over the title still reach the list beneath.
 */
@Composable
private fun HeaderBar(
  title: String,
  subtitle: String?,
  progress: State<Float>,
  topInset: Dp,
  barHeight: Dp,
  trailing: @Composable () -> Unit,
) {
  Box(Modifier.fillMaxWidth()) {
    Box(
      Modifier
        .fillMaxWidth()
        .height(barHeight)
        .clipToBounds()
        .padding(horizontal = Dp.edge)
        .padding(top = topInset + TITLE_TOP),
    ) {
      LargeTitle(title, progress)
      CompactTitle(title, progress)
    }

    if (subtitle != null) {
      Subtitle(
        subtitle = subtitle,
        progress = progress,
        modifier = Modifier
          .padding(top = topInset + SUBTITLE_TOP)
          .padding(horizontal = Dp.edge),
      )
    }

    Box(
      Modifier
        .align(Alignment.TopEnd)
        .padding(top = topInset + TITLE_TOP)
        .padding(horizontal = Dp.edge),
    ) {
      trailing()
    }
  }
}

/**
 * The large wordmark title. It rolls up and out as the header collapses.
 *
 * The only part of the header that recomposes while scrolling, and only because
 * a text shadow's colour lives in its style; everything else reads the
 * progress at draw time.
 */
@Composable
private fun LargeTitle(title: String, progress: State<Float>) {
  val density = LocalDensity.current
  val shadowAlpha = HeaderCollapse.legibilityShadowOpacity(progress.value)
  val style = DeepType.wordmark.copy(
    shadow = with(density) {
      Shadow(
        color = Color.deepPlum.copy(alpha = shadowAlpha),
        offset = Offset(0f, TITLE_SHADOW_Y.toPx()),
        blurRadius = TITLE_SHADOW_RADIUS.toPx(),
      )
    },
  )

  BasicText(
    text = title,
    style = style,
    color = { titleColor(progress.value) },
    maxLines = 1,
    overflow = TextOverflow.Ellipsis,
    modifier = Modifier
      .semantics { heading() }
      .graphicsLayer {
        val p = progress.value
        alpha = HeaderCollapse.largeTitleOpacity(p)
        translationY = HeaderCollapse.largeTitleOffsetY(p).dp.toPx()
      },
  )
}

/**
 * The compact serif-italic title that rises into the bar from just below.
 *
 * Hidden from accessibility: it repeats the large title, which stays the one
 * heading TalkBack reads.
 */
@Composable
private fun CompactTitle(title: String, progress: State<Float>) {
  val style = DeepType.revealTitle

  BasicText(
    text = title,
    style = style,
    color = { titleColor(progress.value) },
    maxLines = 1,
    overflow = TextOverflow.Ellipsis,
    autoSize = TextAutoSize.StepBased(
      minFontSize = style.fontSize * COMPACT_MIN_SCALE,
      maxFontSize = style.fontSize,
    ),
    modifier = Modifier
      .clearAndSetSemantics {}
      .graphicsLayer {
        val p = progress.value
        alpha = HeaderCollapse.compactTitleOpacity(p)
        translationY = HeaderCollapse.compactTitleOffsetY(p).dp.toPx()
      },
  )
}

/** The subtitle — fades first, so the compact bar shows the name only. */
@Composable
private fun Subtitle(subtitle: String, progress: State<Float>, modifier: Modifier = Modifier) {
  val density = LocalDensity.current
  val shadowAlpha = HeaderCollapse.legibilityShadowOpacity(progress.value)
  val style = DeepType.caption.copy(
    shadow = with(density) {
      Shadow(
        color = Color.deepPlum.copy(alpha = shadowAlpha),
        offset = Offset(0f, SUBTITLE_SHADOW_Y.toPx()),
        blurRadius = SUBTITLE_SHADOW_RADIUS.toPx(),
      )
    },
  )

  BasicText(
    text = subtitle,
    style = style,
    color = { Color.White.copy(alpha = SUBTITLE_ALPHA) },
    maxLines = 1,
    overflow = TextOverflow.Ellipsis,
    modifier = modifier.graphicsLayer { alpha = HeaderCollapse.subtitleOpacity(progress.value) },
  )
}

/** White over the video, easing to plum as it lands on the blurred bar. */
private fun titleColor(progress: Float): Color =
  lerp(Color.White, Color.deepPlum, HeaderCollapse.titleColorMixFraction(progress))

// MARK: - Progressive blur

/**
 * The bar's progressive blur, applied to the content it sits over: full at the
 * status bar, dissolving to clear at the bar's lower edge, faded in by
 * [opacity] as the header collapses. The stand-in for iOS's
 * `VariableBlurView(maxBlurRadius: 20, direction: .blurredTopClearBottom)`,
 * whose radius falls linearly from the maximum at the top to zero at the foot.
 *
 * On API 31+ the content is recorded once and that ramp is rebuilt from a few
 * fixed radii ([BLUR_TIERS]): each tier owns the stretch of the band where the
 * ramp passes its radius and hands over to its neighbours through
 * triangular masks that always sum to one, so every row is a blend of the two
 * radii nearest the one iOS would use there. The tiers are summed (`Plus`)
 * inside one isolated layer — an exact crossfade, no darkened seam — which
 * then lands on the atmosphere behind as a single ordinary layer. A single
 * radius crossfaded with the sharp content was tried first and read as a
 * double exposure: sharp text ghosting through its own blur halfway down the
 * bar.
 *
 * Below API 31 there is no blur to draw, so the band is a moonCream wash that
 * fades the same way, painted source-atop so it only frosts content pixels.
 *
 * When the header is expanded the opacity is zero and this draws the content
 * straight through — no recording, no second pass over the hero video.
 */
private fun Modifier.headerBackdrop(barHeight: Dp, opacity: () -> Float): Modifier =
  drawWithCache {
    val barPx = barHeight.toPx()
    val bandSize = Size(size.width, min(barPx, size.height))
    val bandBounds = Rect(Offset.Zero, size)

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      val maxRadiusPx = BLUR_RADIUS.toPx()
      // Record past the band's foot so the blur near it samples real content
      // rather than clamping the last row.
      val blurHeight = ceil(min(size.height, barPx + maxRadiusPx * 2f)).toInt()
      val contentLayer = obtainGraphicsLayer()
      val tierLayers = BLUR_TIERS.map { tier ->
        val radius = maxRadiusPx * tier
        obtainGraphicsLayer().apply {
          renderEffect = BlurEffect(radius, radius, TileMode.Clamp)
          clip = true
        }
      }
      val sumPaint = Paint().apply { blendMode = BlendMode.Plus }

      onDrawWithContent {
        val o = opacity()
        if (o <= 0f || barPx <= 0f) {
          drawContent()
          return@onDrawWithContent
        }

        contentLayer.record { this@onDrawWithContent.drawContent() }

        drawContext.canvas.saveLayer(bandBounds, Paint())
        // Sharp, with every blurred tier's share carved out of the band.
        drawLayer(contentLayer)
        drawRect(
          brush = rampMask(sharpCarveStops(o), barPx),
          size = bandSize,
          blendMode = BlendMode.DstOut,
        )
        // Each tier, kept only where the ramp wants it, summed back in. The
        // mask rect spans the tier's whole recorded height, not just the band:
        // DstIn only erases what it covers, and the band's foot rarely lands
        // on a whole pixel, so a band-sized rect leaves a half-covered row —
        // summed onto the sharp content as a one-pixel bright line.
        val tierSize = IntSize(size.width.toInt(), blurHeight)
        tierLayers.forEachIndexed { index, layer ->
          layer.record(size = tierSize) { drawLayer(contentLayer) }
          drawContext.canvas.saveLayer(Rect(Offset.Zero, tierSize.toSize()), sumPaint)
          drawLayer(layer)
          drawRect(
            brush = rampMask(tierStops(index, o), barPx),
            size = tierSize.toSize(),
            blendMode = BlendMode.DstIn,
          )
          drawContext.canvas.restore()
        }
        drawContext.canvas.restore()
      }
    } else {
      onDrawWithContent {
        val o = opacity()
        if (o <= 0f || barPx <= 0f) {
          drawContent()
          return@onDrawWithContent
        }
        drawContext.canvas.saveLayer(bandBounds, Paint())
        drawContent()
        drawRect(
          brush = Brush.verticalGradient(
            0f to Color.moonCream.copy(alpha = SCRIM_ALPHA * o),
            1f to Color.moonCream.copy(alpha = 0f),
            endY = barPx,
          ),
          size = bandSize,
          blendMode = BlendMode.SrcAtop,
        )
        drawContext.canvas.restore()
      }
    }
  }

/**
 * The blur radii the ramp is rebuilt from, as shares of [BLUR_RADIUS], top
 * down. The radius falls linearly with depth, so a share of r sits at depth
 * 1 − r; the sharp content (radius 0) owns the foot.
 */
private val BLUR_TIERS = listOf(1f, 0.5f, 0.25f)

/** Where each tier peaks in the band, 0 = status-bar top, 1 = the bar's foot. */
private fun tierPosition(index: Int): Float =
  if (index >= BLUR_TIERS.size) 1f else 1f - BLUR_TIERS[index]

/**
 * A tier's triangular share: 1 at its own depth, 0 at its neighbours'. The top
 * tier holds 1 up to the band's top edge.
 */
private fun tierStops(index: Int, opacity: Float): List<Pair<Float, Float>> {
  val here = tierPosition(index)
  val next = tierPosition(index + 1)
  return buildList {
    if (index == 0) {
      add(0f to opacity)
    } else {
      add(tierPosition(index - 1) to 0f)
      add(here to opacity)
    }
    add(next to 0f)
  }
}

/**
 * What the blurred tiers take from the sharp content: everything down to the
 * last tier's depth, then handing back to sharp by the bar's foot.
 */
private fun sharpCarveStops(opacity: Float): List<Pair<Float, Float>> =
  listOf(0f to opacity, tierPosition(BLUR_TIERS.lastIndex) to opacity, 1f to 0f)

/** A vertical alpha mask over the band from (depth, alpha) stops. */
private fun rampMask(stops: List<Pair<Float, Float>>, barPx: Float): Brush =
  Brush.verticalGradient(
    *stops.map { (depth, alpha) -> depth to Color.Black.copy(alpha = alpha) }.toTypedArray(),
    endY = barPx,
  )

// MARK: - Previews

/**
 * A hermetic skeleton in the home-screen shape: a gradient standing in for the
 * sky video (no player in a preview), frosted rows riding up over it, and the
 * atmosphere behind — outside the header, as a real screen keeps it.
 */
@Composable
internal fun CollapsibleHomeHeaderPreviewScreen(
  listState: LazyListState,
  pull: HeroPull,
  nestedScroll: NestedScrollConnection,
  trailing: @Composable () -> Unit = {},
) {
  DeepTheme {
    Box(Modifier.fillMaxSize().background(Color.moonCream)) {
      AtmosphereBackground()
      CollapsibleHomeHeader(
        title = "Home",
        subtitle = "Take a breath with the world today",
        listState = listState,
        trailing = trailing,
      ) {
        LazyColumn(
          state = listState,
          modifier = Modifier.fillMaxSize().nestedScroll(nestedScroll),
          contentPadding = PaddingValues(bottom = Dp.rhythm),
          verticalArrangement = Arrangement.spacedBy(Dp.rhythm),
        ) {
          item {
            StretchyHero(pull = pull, listState = listState) { PreviewSky() }
          }
          items(8) {
            Box(
              Modifier
                .offset(y = -PREVIEW_HERO_OVERLAP)
                .padding(horizontal = Dp.edge)
                .fillMaxWidth()
                .height(PREVIEW_ROW_HEIGHT)
                .frostedCard(),
            )
          }
        }
      }
    }
  }
}

/** A dusk gradient in place of the sky footage. */
@Composable
internal fun PreviewSky() {
  Box(
    Modifier
      .fillMaxSize()
      .background(Brush.verticalGradient(listOf(Color.deepPlum, Color.lavenderMist, Color.softLilac))),
  )
}

private val PREVIEW_HERO_OVERLAP = 80.dp
private val PREVIEW_ROW_HEIGHT = 120.dp

@Preview(showBackground = true, name = "Collapsible header — over hero")
@Composable
private fun CollapsibleHomeHeaderExpandedPreview() {
  val listState = rememberLazyListState()
  val (pull, nestedScroll) = rememberHeroPull(listState)
  CollapsibleHomeHeaderPreviewScreen(listState, pull, nestedScroll)
}

@Preview(showBackground = true, name = "Collapsible header — collapsed")
@Composable
private fun CollapsibleHomeHeaderCollapsedPreview() {
  val listState = rememberLazyListState(initialFirstVisibleItemIndex = 2)
  val (pull, nestedScroll) = rememberHeroPull(listState)
  CollapsibleHomeHeaderPreviewScreen(listState, pull, nestedScroll)
}

@Preview(showBackground = true, name = "Collapsible header — with accessory")
@Composable
private fun CollapsibleHomeHeaderAccessoryPreview() {
  val listState = rememberLazyListState()
  val (pull, nestedScroll) = rememberHeroPull(listState)
  CollapsibleHomeHeaderPreviewScreen(listState, pull, nestedScroll) {
    // A stand-in balance that flips with the title, as HeartBalanceChip does.
    val overHero = LocalHeaderOverDarkHero.current
    BasicText(
      text = "2,450",
      style = DeepType.counter,
      color = { if (overHero) Color.White else Color.deepPlum },
    )
  }
}
