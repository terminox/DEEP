package io.appbeyond.freelance.deep.feature.globalpause

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.globalpause.components.ContinentLights
import io.appbeyond.freelance.deep.feature.globalpause.globe.PlaceholderGlobeRendering
import io.appbeyond.freelance.deep.feature.globalpause.model.ContinentPresence
import io.appbeyond.freelance.deep.shared.components.rememberReduceMotion
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.bloom
import io.appbeyond.freelance.deep.theme.blushPowder
import io.appbeyond.freelance.deep.theme.chip
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.frostedCard
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import java.text.NumberFormat
import java.time.Duration
import kotlin.math.roundToInt

/**
 * The live meditation's overlay, over the night sky and the globe — and
 * deliberately near-empty: a LIVE mark, a gentle count of company, the world
 * named beneath the globe, a thin progress line. No transport: the absence of
 * controls is how "cannot be paused" looks. The session's close button is the
 * only exit, and it sits outside this view.
 *
 * It arrives empty and cascades in once the presentation has landed
 * ([revealed]) — pill, count, continents, progress — each with a small lift.
 * Reduce motion keeps the fades and drops the lift. Nothing here is touchable,
 * so every touch reaches the globe beneath.
 *
 * Ported from Deep/Deep/Features/GlobalPause/Screens/GlobalPauseMeditationView.swift.
 *
 * @param elapsed how far the shared stream has actually played — the player's
 *   clock, the honest source for the progress line.
 */
@Composable
fun GlobalPauseMeditationOverlay(
  elapsed: Duration,
  duration: Duration,
  participantCount: Int,
  continents: List<ContinentPresence>,
  revealed: Boolean,
  modifier: Modifier = Modifier,
) {
  val reduceMotion = rememberReduceMotion()

  Column(
    modifier
      .fillMaxSize()
      .statusBarsPadding()
      .navigationBarsPadding(),
    horizontalAlignment = Alignment.CenterHorizontally,
  ) {
    Spacer(Modifier.height(68.dp))
    LiveCapsule(Modifier.cascade(revealed, order = 0, reduceMotion))

    // Before the first poll the count is 0 and there is nothing true to say, so
    // the line isn't there — the same silence the continents row keeps.
    AnimatedVisibility(visible = participantCount > 0, enter = fadeIn(bloom()), exit = fadeOut(bloom())) {
      val formatted = NumberFormat.getIntegerInstance(LocalConfiguration.current.locales[0]).format(participantCount)
      Text(
        pluralStringResource(R.plurals.pause_company, participantCount, formatted),
        style = DeepType.caption,
        // moonCream, not driftGrey — the caption sits on the night sky.
        color = Color.moonCream.copy(alpha = 0.75f),
        modifier = Modifier
          .padding(top = 12.dp)
          .cascade(revealed, order = 1, reduceMotion),
      )
    }

    Spacer(Modifier.weight(1f))

    AnimatedVisibility(visible = continents.isNotEmpty(), enter = fadeIn(bloom()), exit = fadeOut(bloom())) {
      ContinentLights(
        presences = continents,
        modifier = Modifier
          .padding(horizontal = 12.dp)
          .padding(bottom = 48.dp)
          .cascade(revealed, order = 2, reduceMotion),
      )
    }

    ProgressLine(
      elapsed = elapsed,
      duration = duration,
      modifier = Modifier
        .padding(horizontal = 44.dp)
        .padding(bottom = 40.dp)
        .cascade(revealed, order = 3, reduceMotion),
    )
  }
}

@Composable
private fun LiveCapsule(modifier: Modifier = Modifier) {
  val spoken = stringResource(R.string.pause_meditation_live_a11y)
  Row(
    modifier
      .clearAndSetSemantics { contentDescription = spoken }
      .frostedCard(cornerRadius = Dp.chip)
      .padding(horizontal = 14.dp, vertical = 8.dp),
    horizontalArrangement = Arrangement.spacedBy(8.dp),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    Box(Modifier.size(7.dp).background(Color.blushPowder, CircleShape))
    Text(stringResource(R.string.pause_meditation_live), style = DeepType.micro, color = Color.deepPlum)
  }
}

/** Player-driven: the audio clock publishes every half-second. */
@Composable
private fun ProgressLine(elapsed: Duration, duration: Duration, modifier: Modifier = Modifier) {
  val progress = if (duration.isZero) 0f else (elapsed.toMillis().toFloat() / duration.toMillis()).coerceIn(0f, 1f)
  val percent = (progress * 100).roundToInt()
  val spoken = stringResource(R.string.pause_meditation_progress_a11y, percent)
  Box(
    modifier
      .fillMaxWidth()
      .height(8.dp)
      .clip(RoundedCornerShape(Dp.chip))
      .background(Color.moonCream.copy(alpha = 0.18f))
      .clearAndSetSemantics { contentDescription = spoken },
  ) {
    Box(
      Modifier
        .fillMaxWidth(progress)
        .height(8.dp)
        .clip(RoundedCornerShape(Dp.chip))
        .background(Brush.horizontalGradient(listOf(Color.lavenderMist, Color.blushPowder))),
    )
  }
}

/**
 * One step of the arrival cascade: a fade and a small rise, staggered by
 * [order] on the bloom curve. Reduce motion keeps the fade, drops the rise.
 */
@Composable
private fun Modifier.cascade(revealed: Boolean, order: Int, reduceMotion: Boolean): Modifier {
  val curve = bloom<Float>()
  val spec = tween<Float>(
    durationMillis = curve.durationMillis,
    delayMillis = if (revealed) order * CASCADE_STEP_MILLIS else 0,
    easing = curve.easing,
  )
  val alpha by animateFloatAsState(if (revealed) 1f else 0f, spec, label = "cascade-alpha")
  val rise by animateFloatAsState(if (revealed || reduceMotion) 0f else CASCADE_RISE_DP, spec, label = "cascade-rise")
  val density = LocalDensity.current
  return graphicsLayer {
    this.alpha = alpha
    translationY = with(density) { rise.dp.toPx() }
  }
}

private const val CASCADE_STEP_MILLIS = 120
private const val CASCADE_RISE_DP = 12f

@Preview(name = "Meditation")
@Composable
private fun MeditationPreview() {
  DeepTheme {
    Box(Modifier.fillMaxSize()) {
      PlaceholderGlobeRendering.NightSky(Modifier.fillMaxSize())
      GlobalPauseMeditationOverlay(
        elapsed = Duration.ofMinutes(5),
        duration = Duration.ofMinutes(10),
        participantCount = 4218,
        continents = ContinentPresence.row(mapOf("AS" to 1842, "EU" to 1106, "NA" to 604, "SA" to 199, "AF" to 291, "OC" to 176)),
        revealed = true,
      )
    }
  }
}

@Preview(name = "Meditation — alone")
@Composable
private fun MeditationAlonePreview() {
  DeepTheme {
    Box(Modifier.fillMaxSize()) {
      PlaceholderGlobeRendering.NightSky(Modifier.fillMaxSize())
      GlobalPauseMeditationOverlay(
        elapsed = Duration.ofMinutes(1),
        duration = Duration.ofMinutes(10),
        participantCount = 1,
        continents = emptyList(),
        revealed = true,
      )
    }
  }
}
