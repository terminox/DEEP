package io.appbeyond.freelance.deep.feature.onboarding.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.ProgressBarRangeInfo
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.progressBarRangeInfo
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.chip
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.exhale
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.rhythm
import io.appbeyond.freelance.deep.theme.softLilac
import kotlin.math.roundToInt

private val TRACK_HEIGHT = 6.dp
private val LABEL_SPACING = 12.dp
private const val TRACK_ALPHA = 0.4f

/**
 * A slim capsule that fills from 0 to 1 with the slow [exhale], plus an optional
 * "2 of 6" label.
 *
 * Ported from Deep/Deep/Features/Onboarding/Components/OnboardingProgressBar.swift.
 * Read by TalkBack as one element — "Progress, 50 percent" — rather than a bar
 * and a stray number.
 */
@Composable
fun OnboardingProgressBar(
  progress: Float,
  modifier: Modifier = Modifier,
  fractionLabel: String? = null,
) {
  val clamped = progress.coerceIn(0f, 1f)
  val fill by animateFloatAsState(targetValue = clamped, animationSpec = exhale(), label = "onboarding-progress")
  val label = stringResource(R.string.onboarding_progress)
  val percent = stringResource(R.string.onboarding_progress_percent, (clamped * 100).roundToInt())
  val shape = RoundedCornerShape(Dp.chip)

  Row(
    modifier = modifier.clearAndSetSemantics {
      contentDescription = label
      stateDescription = percent
      progressBarRangeInfo = ProgressBarRangeInfo(clamped, 0f..1f)
    },
    horizontalArrangement = Arrangement.spacedBy(LABEL_SPACING),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    Box(
      Modifier
        .weight(1f)
        .height(TRACK_HEIGHT)
        .clip(shape)
        .background(Color.softLilac.copy(alpha = TRACK_ALPHA)),
    ) {
      Box(
        Modifier
          .fillMaxHeight()
          .fillMaxWidth(fill)
          .clip(shape)
          .background(Color.lavenderMist),
      )
    }

    if (fractionLabel != null) {
      Text(text = fractionLabel, style = DeepType.micro, color = Color.driftGrey)
    }
  }
}

@Preview(showBackground = true, name = "Progress bar")
@Composable
private fun OnboardingProgressBarPreview() {
  OnboardingPreviewBackdrop {
    Column(
      modifier = Modifier.padding(horizontal = Dp.edge, vertical = Dp.rhythm),
      verticalArrangement = Arrangement.spacedBy(Dp.rhythm),
    ) {
      OnboardingProgressBar(progress = 0.16f)
      OnboardingProgressBar(progress = 0.5f, fractionLabel = "3 of 6")
      OnboardingProgressBar(progress = 1f)
    }
  }
}
