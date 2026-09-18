package io.appbeyond.freelance.deep.feature.deepsession

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.deepsession.model.DeepSession
import io.appbeyond.freelance.deep.feature.deepsession.model.DeepSessionLength
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.bloom
import io.appbeyond.freelance.deep.theme.chip
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.rhythm
import io.appbeyond.freelance.deep.theme.softLilac
import io.appbeyond.freelance.deep.theme.softPress
import kotlin.math.roundToInt

/**
 * The threshold you cross before a practice begins.
 *
 * The chosen length **is** the screen's subject — a numeral standing far above
 * every other token in the scale, with its unit quietly beneath. Everything else
 * on the screen is smaller than it on purpose.
 *
 * Ported from Deep/Deep/Features/DeepSession/Screens/DeepSessionIntroView.swift.
 */
@Composable
fun DeepSessionIntroScreen(
  session: DeepSession,
  minutes: Int,
  onMinutesChange: (Int) -> Unit,
  onBegin: () -> Unit,
  modifier: Modifier = Modifier,
) {
  val chosen = session.lasting(minutes)

  Box(
    modifier
      .fillMaxSize()
      .background(Color.moonCream),
  ) {
    AtmosphereBackground()

    Column(
      Modifier
        .fillMaxSize()
        .safeDrawingPadding()
        .padding(horizontal = Dp.edge),
      horizontalAlignment = Alignment.CenterHorizontally,
      verticalArrangement = Arrangement.Center,
    ) {
      Text(
        text = session.title,
        style = DeepType.displayTitle,
        color = Color.deepPlum,
        textAlign = TextAlign.Center,
      )

      if (session.tagline.isNotEmpty()) {
        Text(
          text = session.tagline,
          style = DeepType.body,
          color = Color.driftGrey,
          textAlign = TextAlign.Center,
          modifier = Modifier.padding(top = 8.dp),
        )
      }

      Spacer(Modifier.height(Dp.rhythm))

      // The numeral and its unit. Tabular figures keep it from shifting sideways
      // as the slider rolls it between values.
      Row(verticalAlignment = Alignment.Bottom) {
        Text(
          text = minutes.toString(),
          style = DeepType.heroNumber,
          color = Color.deepPlum,
        )
        Text(
          text = stringResource(R.string.session_minutes),
          style = DeepType.body,
          color = Color.driftGrey,
          modifier = Modifier.padding(start = 6.dp, bottom = 18.dp),
        )
      }

      AnimatedContent(
        targetState = chosen.cycles,
        transitionSpec = { fadeIn(bloom()) togetherWith fadeOut(bloom()) },
        label = "session-pattern",
      ) { rounds ->
        Text(
          text = stringResource(R.string.session_pattern, rounds),
          style = DeepType.caption,
          color = Color.driftGrey,
          textAlign = TextAlign.Center,
        )
      }

      Spacer(Modifier.height(Dp.rhythm))

      Slider(
        value = minutes.toFloat(),
        onValueChange = { onMinutesChange(it.roundToInt()) },
        valueRange = DeepSessionLength.range.first.toFloat()..DeepSessionLength.range.last.toFloat(),
        steps = DeepSessionLength.range.last - DeepSessionLength.range.first - 1,
        colors = SliderDefaults.colors(
          thumbColor = Color.lavenderMist,
          activeTrackColor = Color.lavenderMist,
          inactiveTrackColor = Color.softLilac.copy(alpha = 0.45f),
          activeTickColor = Color.Transparent,
          inactiveTickColor = Color.Transparent,
        ),
        modifier = Modifier.fillMaxWidth(),
      )

      Spacer(Modifier.height(Dp.rhythm))

      BeginButton(onClick = onBegin)
    }
  }
}

/**
 * The key action.
 *
 * A gradient pill rather than a solid fill — a flat plum block is alien in this
 * palette, and the app's key actions are built by composing what already exists
 * rather than by inventing a new style for each one.
 */
@Composable
private fun BeginButton(onClick: () -> Unit, modifier: Modifier = Modifier) {
  Box(
    modifier
      .clip(RoundedCornerShape(Dp.chip))
      .background(
        Brush.horizontalGradient(listOf(Color.lavenderMist, Color.softLilac))
      )
      .softPress()
      .clickable(onClick = onClick)
      .padding(horizontal = 44.dp, vertical = 16.dp),
    contentAlignment = Alignment.Center,
  ) {
    Text(
      text = stringResource(R.string.session_begin),
      style = DeepType.bodyMedium,
      color = Color.White,
    )
  }
}

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
    )
  }
}
