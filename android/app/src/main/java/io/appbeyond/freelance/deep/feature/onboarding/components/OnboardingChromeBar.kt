package io.appbeyond.freelance.deep.feature.onboarding.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.theme.chip
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.frostedCard
import io.appbeyond.freelance.deep.theme.rhythm
import io.appbeyond.freelance.deep.theme.softPress

/**
 * The chrome row's fixed height. Routed screens pad their top by this much
 * (below the status bar) so content never slides beneath the back button —
 * iOS's `OnboardingChromeBar.height`.
 */
val OnboardingChromeHeight: Dp = 44.dp

private val BACK_BUTTON_SIZE = 40.dp
private val BACK_GLYPH_SIZE = 22.dp
private val ROW_SPACING = 12.dp

/**
 * The persistent onboarding chrome the coordinator floats above the
 * transitioning screens: a frosted back button and — on the quiz and Mind Tree
 * steps — the progress bar. Because it sits outside the crossfading content,
 * the bar holds perfectly still while screens hand off beneath it; only its
 * fill glides.
 *
 * Ported from Deep/Deep/Features/Onboarding/Components/OnboardingChromeBar.swift.
 * Sits below the status bar on its own ([statusBarsPadding]), since the app
 * draws edge to edge.
 *
 * @param progress 0..1 fill, or null to show only the back button (auth screens).
 * @param fractionLabel the "1 of 3" beside the bar.
 */
@Composable
fun OnboardingChromeBar(
  onBack: () -> Unit,
  modifier: Modifier = Modifier,
  progress: Float? = null,
  fractionLabel: String? = null,
) {
  Row(
    modifier = modifier
      .fillMaxWidth()
      .statusBarsPadding()
      .height(OnboardingChromeHeight)
      .padding(horizontal = Dp.edge),
    horizontalArrangement = Arrangement.spacedBy(ROW_SPACING),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    Box(
      modifier = Modifier
        .size(BACK_BUTTON_SIZE)
        .frostedCard(cornerRadius = Dp.chip)
        .softPress()
        .clickable(
          role = Role.Button,
          interactionSource = null,
          indication = null,
          onClick = onBack,
        ),
      contentAlignment = Alignment.Center,
    ) {
      Icon(
        imageVector = OnboardingGlyphs.ChevronBack,
        contentDescription = stringResource(R.string.onboarding_back),
        tint = Color.deepPlum,
        modifier = Modifier.size(BACK_GLYPH_SIZE),
      )
    }

    if (progress != null) {
      OnboardingProgressBar(
        progress = progress,
        fractionLabel = fractionLabel,
        modifier = Modifier.weight(1f),
      )
    } else {
      Spacer(Modifier.weight(1f))
    }
  }
}

@Preview(showBackground = true, name = "Chrome — quiz step and back only")
@Composable
private fun OnboardingChromeBarPreview() {
  OnboardingPreviewBackdrop {
    Column(verticalArrangement = Arrangement.spacedBy(Dp.rhythm)) {
      OnboardingChromeBar(onBack = {}, progress = 1f / 3f, fractionLabel = "1 of 3")
      OnboardingChromeBar(onBack = {})
    }
  }
}
