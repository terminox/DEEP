package io.appbeyond.freelance.deep.feature.mindgarden.components

import androidx.compose.animation.Crossfade
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.PathData
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.deepsound.SoundIcons
import io.appbeyond.freelance.deep.feature.mindgarden.model.GardenState
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.CompassionRing
import io.appbeyond.freelance.deep.shared.components.RingSegment
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.blushPowder
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.exhale
import io.appbeyond.freelance.deep.theme.frostedCard
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.softLilac
import io.appbeyond.freelance.deep.theme.softPress

// MARK: - Constants

private val CARD_PADDING = 20.dp
private val ROW_SPACING = 16.dp

/** Eyebrow, headline and subtitle — iOS's `VStack(spacing: 5)`. */
private val COPY_SPACING = 5.dp

/** Dial to the minutes beneath it — iOS's `VStack(spacing: 6)`. */
private val DIAL_SPACING = 6.dp

/** Today's ring around the play button — iOS's 69pt frame, 3.5 stroke. */
private val RING_SIZE = 69.dp
private val RING_WIDTH = 3.5.dp

/** The play button itself. */
private val PLAY_SIZE = 54.dp

/** The play / check glyph — iOS's 18pt semibold symbol, measured to its box. */
private val GLYPH_SIZE = 22.dp

/** The bloom under the play button — iOS's `shadow(lavenderMist 0.4, radius: 12, y: 6)`. */
private const val PLAY_BLOOM_ALPHA = 0.4f
private val PLAY_BLOOM_RADIUS = 12.dp
private val PLAY_BLOOM_OFFSET_Y = 6.dp

/**
 * The minutes under the ring: the micro size without the eyebrow's tracking —
 * iOS tracks only the eyebrow — and in tabular digits so "7" → "8" never shifts.
 */
private val MINUTES_STYLE = DeepType.micro.copy(letterSpacing = 0.sp, fontFeatureSettings = "tnum")

// MARK: - Card

/**
 * The primary call to action on the garden home — a gentle nudge into today's
 * practice. Today's progress rides the play button itself as a soft ring, with
 * the minutes resting beneath it, so the card stays a single quiet row.
 *
 * Ported from Deep/Deep/Features/MindGarden/Components/DailyPracticeCard.swift.
 * The card stays a dumb button; the screen decides what tapping it does. The
 * whole card is the hit target and speaks as one sentence to TalkBack.
 *
 * @param plantName the selected plant's display name ("Sakura"); null while the
 *   garden is still loading, when the copy falls back to "garden".
 */
@Composable
fun DailyPracticeCard(
  state: GardenState,
  onClick: () -> Unit,
  modifier: Modifier = Modifier,
  plantName: String? = null,
) {
  val complete = state.minutesRemaining == 0
  val headline = stringResource(
    if (complete) R.string.practice_headline_complete else R.string.practice_headline_tend,
  )
  val subtitle = if (complete) {
    stringResource(R.string.practice_subtitle_complete)
  } else {
    stringResource(
      R.string.practice_subtitle_feeds,
      plantName?.lowercase() ?: stringResource(R.string.practice_subtitle_garden),
    )
  }
  val summary = pluralStringResource(
    if (complete) R.plurals.practice_summary_complete else R.plurals.practice_summary_begin,
    state.dailyGoalMinutes,
    state.minutesToday,
    state.dailyGoalMinutes,
  )

  Row(
    modifier
      .fillMaxWidth()
      .softPress()
      .frostedCard()
      .clickable(interactionSource = null, indication = null, onClick = onClick)
      .clearAndSetSemantics {
        contentDescription = summary
        role = Role.Button
        onClick { onClick(); true }
      }
      .padding(CARD_PADDING),
    horizontalArrangement = Arrangement.spacedBy(ROW_SPACING),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    Column(
      Modifier.weight(1f),
      verticalArrangement = Arrangement.spacedBy(COPY_SPACING),
    ) {
      Text(stringResource(R.string.practice_eyebrow), style = DeepType.micro, color = Color.driftGrey)
      Text(headline, style = DeepType.displayTitle, color = Color.deepPlum)
      Text(subtitle, style = DeepType.caption, color = Color.driftGrey)
    }

    ProgressDial(state = state, complete = complete)
  }
}

/**
 * The play button inside today's ring, minutes beneath — one column that tells
 * the whole progress story without a separate meter row.
 */
@Composable
private fun ProgressDial(state: GardenState, complete: Boolean) {
  Column(
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalArrangement = Arrangement.spacedBy(DIAL_SPACING),
  ) {
    CompassionRing(
      segments = listOf(
        RingSegment(share = state.progress.toFloat(), colors = listOf(Color.lavenderMist, Color.blushPowder)),
      ),
      lineWidth = RING_WIDTH,
      gap = 0f,
      modifier = Modifier.size(RING_SIZE),
    ) {
      PlayCircle(complete = complete)
    }
    Text(
      stringResource(R.string.practice_minutes, state.minutesToday, state.dailyGoalMinutes),
      style = MINUTES_STYLE,
      color = Color.driftGrey,
    )
  }
}

@Composable
private fun PlayCircle(complete: Boolean) {
  Box(
    Modifier
      .size(PLAY_SIZE)
      .dropShadow(
        shape = CircleShape,
        shadow = Shadow(
          radius = PLAY_BLOOM_RADIUS,
          color = Color.lavenderMist.copy(alpha = PLAY_BLOOM_ALPHA),
          offset = DpOffset(0.dp, PLAY_BLOOM_OFFSET_Y),
        ),
      )
      .background(Brush.linearGradient(listOf(Color.lavenderMist, Color.softLilac)), CircleShape),
    contentAlignment = Alignment.Center,
  ) {
    // The goal closing turns play into a check — eased, as the ring around it is.
    Crossfade(targetState = complete, animationSpec = exhale(), label = "practice-glyph") { done ->
      Icon(
        imageVector = if (done) CheckGlyph else SoundIcons.Play,
        contentDescription = null,
        tint = Color.White,
        modifier = Modifier.size(GLYPH_SIZE),
      )
    }
  }
}

/**
 * iOS's semibold `checkmark` — the goal closed. A 2.25 stroke, the semibold
 * weight the sun glyph's rays use, so it holds its own beside the solid play.
 */
private val CheckGlyph: ImageVector = ImageVector.Builder(
  name = "GardenCheck",
  defaultWidth = 24.dp,
  defaultHeight = 24.dp,
  viewportWidth = 24f,
  viewportHeight = 24f,
).addPath(
  pathData = PathData {
    moveTo(5.5f, 12.5f)
    lineTo(10f, 17f)
    lineTo(18.5f, 7.5f)
  },
  fill = null,
  stroke = SolidColor(Color.Black), // replaced by the Icon tint at the call site
  strokeLineWidth = 2.25f,
  strokeLineCap = StrokeCap.Round,
  strokeLineJoin = StrokeJoin.Round,
).build()

// MARK: - Previews

@Preview(showBackground = true, name = "Daily practice")
@Composable
private fun DailyPracticeCardPreview() {
  DeepTheme {
    Box(Modifier.fillMaxSize().background(Color.moonCream)) {
      AtmosphereBackground(animated = false)
      Column(
        Modifier.padding(Dp.edge),
        verticalArrangement = Arrangement.spacedBy(ROW_SPACING),
      ) {
        DailyPracticeCard(state = GardenState.sample, plantName = "Oak", onClick = {})
        DailyPracticeCard(state = GardenState.fresh, plantName = "Sakura", onClick = {})
        // No plant yet (garden still loading) — the copy falls back to "garden".
        DailyPracticeCard(state = GardenState.fresh, onClick = {})
        DailyPracticeCard(state = GardenState.flourishing, plantName = "Oak", onClick = {})
      }
    }
  }
}
