package io.appbeyond.freelance.deep.feature.deepsession

import android.content.Context
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.hideFromAccessibility
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.core.content.edit
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.deepsession.model.DeepSession
import io.appbeyond.freelance.deep.feature.deepsession.model.DeepSessionLength
import io.appbeyond.freelance.deep.feature.deepsound.SoundIcons
import io.appbeyond.freelance.deep.feature.profile.HeaderIconButton
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.LocalMiniPlayerClearance
import io.appbeyond.freelance.deep.shared.components.RollingText
import io.appbeyond.freelance.deep.shared.components.rememberReduceMotion
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.bloom
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.drift
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.hush
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.rhythm
import io.appbeyond.freelance.deep.theme.softLilac
import io.appbeyond.freelance.deep.theme.softPress
import kotlin.math.roundToInt
import kotlin.time.DurationUnit

/**
 * The threshold before a DEEP Session — a quiet page where you set how long
 * the practice runs, see what it holds, and step in. Pushed onto the launching
 * tab's stack by the shell, so the tab bar and mini player stay, while Begin
 * lifts the practice up over the whole shell ([DeepSessionCoordinator]).
 *
 * This is the stateful edge: it titles the practice from resources (the model
 * type in :core:model knows nothing about them) as iOS's
 * `DeepSessionLibrary.balancingBreath`, and remembers the chosen length between
 * visits. The layout is the stateless overload below.
 *
 * @param session the practice the entry card offered; its pattern is what runs.
 * @param onBegin starts the practice at the length now chosen.
 * @param onBack the back chevron. System back is the shell's own pop.
 * @param isRunning true while the practice covers this screen — the beat it
 *   answers with its own half of the lift.
 */
@Composable
fun DeepSessionIntroScreen(
  session: DeepSession,
  onBegin: (DeepSession) -> Unit,
  onBack: () -> Unit,
  modifier: Modifier = Modifier,
  isRunning: Boolean = false,
) {
  val context = LocalContext.current
  var minutes by remember { mutableIntStateOf(readMinutes(context)) }
  val titled = session.copy(
    title = stringResource(R.string.deepsound_balancing_breath_title),
    tagline = stringResource(R.string.deepsound_balancing_breath_tagline),
  )

  DeepSessionIntroScreen(
    session = titled,
    minutes = minutes,
    onMinutesChange = {
      minutes = it
      writeMinutes(context, it)
    },
    onBegin = { onBegin(titled.lasting(minutes)) },
    onBack = onBack,
    modifier = modifier,
    isRunning = isRunning,
  )
}

/**
 * The threshold's layout. The length is the screen's subject, so the chosen
 * numeral stands on the screen's own centre line with its unit tucked
 * underneath — set beside it, the unit's width would push the numeral off
 * centre. Everything the practice says about itself follows, and the one
 * control that sets the length closes the column next to the Begin it feeds.
 *
 * Ported from Deep/Deep/Features/DeepSession/Screens/DeepSessionIntroView.swift.
 * iOS's system back chevron over a hidden bar becomes the house's frosted
 * [HeaderIconButton], as on every other pushed screen.
 */
@Composable
fun DeepSessionIntroScreen(
  session: DeepSession,
  minutes: Int,
  onMinutesChange: (Int) -> Unit,
  onBegin: () -> Unit,
  onBack: () -> Unit,
  modifier: Modifier = Modifier,
  isRunning: Boolean = false,
) {
  val chosen = session.lasting(minutes)
  val reduceMotion = rememberReduceMotion()
  // This screen's half of the lift: the content rises as the practice fades
  // up over it. Only the content — the base and the atmosphere stay anchored,
  // so no gap can open at an edge.
  val lift by animateDpAsState(
    targetValue = if (isRunning && !reduceMotion) -Dp.drift else 0.dp,
    animationSpec = hush(),
    label = "threshold-lift",
  )

  Box(
    modifier
      .fillMaxSize()
      .background(Color.moonCream),
  ) {
    AtmosphereBackground()

    Column(
      Modifier
        .fillMaxSize()
        .offset { IntOffset(0, lift.roundToPx()) }
        .statusBarsPadding()
        .padding(horizontal = Dp.edge)
        .padding(bottom = Dp.rhythm + LocalMiniPlayerClearance.current),
      horizontalAlignment = Alignment.CenterHorizontally,
    ) {
      Spacer(Modifier.weight(1f))

      LengthReadout(minutes = minutes)

      Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(TITLE_SPACING),
        modifier = Modifier.padding(top = Dp.rhythm * 1.5f),
      ) {
        Text(
          text = session.title,
          style = DeepType.displayTitle,
          color = Color.deepPlum,
          textAlign = TextAlign.Center,
        )
        Text(
          text = session.tagline,
          style = DeepType.caption,
          color = Color.driftGrey,
          textAlign = TextAlign.Center,
        )
      }

      // A quiet crossfade as the rounds follow the slider — the numeral above
      // is the one thing on this screen allowed to roll.
      AnimatedContent(
        targetState = chosen.cycles,
        transitionSpec = { fadeIn(bloom()) togetherWith fadeOut(bloom()) },
        label = "session-pattern",
        modifier = Modifier.padding(top = Dp.rhythm),
      ) { rounds ->
        Text(
          text = stringResource(
            R.string.session_pattern,
            session.inhale.toInt(DurationUnit.SECONDS),
            session.exhale.toInt(DurationUnit.SECONDS),
            rounds,
          ),
          style = DeepType.caption,
          color = Color.driftGrey.copy(alpha = PATTERN_ALPHA),
          textAlign = TextAlign.Center,
        )
      }

      LengthSlider(
        minutes = minutes,
        onMinutesChange = onMinutesChange,
        modifier = Modifier.padding(top = Dp.rhythm * 1.5f),
      )

      // The track ends the column, so at the largest text sizes it is the
      // thing Begin closes on: keep a gap between them however little room is
      // left, and let the space above take the squeeze.
      Spacer(Modifier.heightIn(min = Dp.rhythm).weight(1f))

      BeginButton(
        accessibilityLabel = stringResource(R.string.session_begin_accessibility, session.title, minutes),
        onClick = onBegin,
      )
    }

    HeaderIconButton(
      icon = SoundIcons.ChevronBack,
      contentDescription = stringResource(R.string.deepsound_back),
      onClick = onBack,
      modifier = Modifier
        .align(Alignment.TopStart)
        .statusBarsPadding()
        .padding(start = Dp.edge, top = BACK_TOP_PADDING),
    )
  }
}

/**
 * The length being chosen: the numeral on the centre line, "MIN" beneath it.
 * Hidden from TalkBack — the slider below speaks for both, and is the thing
 * that can change it.
 */
@Composable
private fun LengthReadout(minutes: Int) {
  Column(
    horizontalAlignment = Alignment.CenterHorizontally,
    // Negative, because the numeral's line box reserves a descender the digits
    // never use: it is the gap under the glyph being closed, not under the text.
    verticalArrangement = Arrangement.spacedBy(READOUT_TUCK),
    modifier = Modifier.semantics { hideFromAccessibility() },
  ) {
    RollingText(
      text = minutes.toString(),
      value = minutes.toFloat(),
      style = DeepType.heroNumber,
      color = Color.deepPlum,
    )
    Text(
      text = stringResource(R.string.session_minutes),
      style = DeepType.micro,
      color = Color.driftGrey,
    )
  }
}

/**
 * The one control that sets the length — the system slider, for the thumb: a
 * value placed by hand should show what the hand is holding. A tick at each
 * minute, so the length can be set by feel.
 */
@Composable
private fun LengthSlider(
  minutes: Int,
  onMinutesChange: (Int) -> Unit,
  modifier: Modifier = Modifier,
) {
  val haptics = LocalHapticFeedback.current
  val range = DeepSessionLength.range
  val label = stringResource(R.string.session_length)
  val value = pluralStringResource(R.plurals.session_length_minutes, minutes, minutes)

  Slider(
    // The clamp keeps a stored value from an older range inside the offer.
    value = minutes.coerceIn(range).toFloat(),
    onValueChange = {
      val next = it.roundToInt().coerceIn(range)
      if (next != minutes) {
        haptics.performHapticFeedback(HapticFeedbackType.SegmentTick)
        onMinutesChange(next)
      }
    },
    valueRange = range.first.toFloat()..range.last.toFloat(),
    steps = range.last - range.first - 1,
    colors = SliderDefaults.colors(
      thumbColor = Color.lavenderMist,
      activeTrackColor = Color.lavenderMist,
      inactiveTrackColor = Color.softLilac.copy(alpha = INACTIVE_TRACK_ALPHA),
      activeTickColor = Color.Transparent,
      inactiveTickColor = Color.Transparent,
    ),
    modifier = modifier
      .fillMaxWidth()
      .padding(horizontal = Dp.edge)
      .semantics {
        contentDescription = label
        stateDescription = value
      },
  )
}

/**
 * The key action: a full-width gradient capsule on the lavender bloom. A flat
 * plum block is alien in this palette; the app's key actions are composed
 * from what already exists rather than invented per screen.
 */
@Composable
private fun BeginButton(
  accessibilityLabel: String,
  onClick: () -> Unit,
  modifier: Modifier = Modifier,
) {
  val shape = RoundedCornerShape(percent = 50)
  Box(
    modifier
      .fillMaxWidth()
      .height(BEGIN_HEIGHT)
      .softPress()
      .dropShadow(
        shape = shape,
        shadow = Shadow(
          radius = BLOOM_RADIUS,
          color = Color.lavenderMist.copy(alpha = BLOOM_ALPHA),
          offset = DpOffset(0.dp, BLOOM_OFFSET_Y),
        ),
      )
      .background(Brush.linearGradient(listOf(Color.lavenderMist, Color.softLilac)), shape)
      // iOS's accessibilityLabel: the button says what it begins, and for how long.
      .semantics { contentDescription = accessibilityLabel }
      .clickable(
        role = Role.Button,
        interactionSource = null,
        indication = null,
        onClick = onClick,
      ),
    contentAlignment = Alignment.Center,
  ) {
    Text(
      text = stringResource(R.string.session_begin),
      style = DeepType.body.copy(fontWeight = FontWeight.SemiBold),
      color = Color.White,
      modifier = Modifier.clearAndSetSemantics {},
    )
  }
}

/*
 * The chosen length persists across visits — every visit after the first opens
 * on whatever was last chosen. One integer, so it stays in SharedPreferences
 * rather than earning a DataStore; the key matches the iOS @AppStorage key so
 * the two platforms describe the same setting.
 */

private const val PREFS = "deep.session"
private const val KEY_MINUTES = "deep.session.minutes"

private fun readMinutes(context: Context): Int =
  context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    .getInt(KEY_MINUTES, DeepSessionLength.opening)
    .coerceIn(DeepSessionLength.range)

private fun writeMinutes(context: Context, minutes: Int) {
  context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit { putInt(KEY_MINUTES, minutes) }
}

private val TITLE_SPACING = 8.dp
private val READOUT_TUCK = (-10).dp
private val BACK_TOP_PADDING = 8.dp
private const val PATTERN_ALPHA = 0.8f
private const val INACTIVE_TRACK_ALPHA = 0.45f

/** iOS's `frame(height: 56)` capsule and its `shadow(lavenderMist 0.4, radius: 12, y: 6)`. */
private val BEGIN_HEIGHT = 56.dp
private const val BLOOM_ALPHA = 0.4f
private val BLOOM_RADIUS = 12.dp
private val BLOOM_OFFSET_Y = 6.dp

@Preview(showBackground = true)
@Composable
private fun DeepSessionIntroScreenPreview() {
  DeepTheme {
    DeepSessionIntroScreen(
      session = DeepSession(
        id = "preview",
        title = "Balancing breath",
        tagline = "Slow breathing to settle back into now",
        cycles = 6,
      ),
      minutes = 3,
      onMinutesChange = {},
      onBegin = {},
      onBack = {},
    )
  }
}
