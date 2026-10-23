package io.appbeyond.freelance.deep.feature.onboarding.components

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.bloom
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.rhythm

private val ROW_SPACING = 14.dp
private const val RING_ALPHA = 0.4f

/**
 * One line of the "shaping your space" loader: a hollow ring that blooms into
 * a lavender check as its step completes, the title brightening from drift
 * grey to plum with it.
 *
 * Ported from Deep/Deep/Features/Onboarding/Components/CraftingChecklistRow.swift.
 * TalkBack reads the row as one element with a done / in-progress state.
 */
@Composable
fun CraftingChecklistRow(
  title: String,
  isDone: Boolean,
  modifier: Modifier = Modifier,
) {
  val textColor by animateColorAsState(
    targetValue = if (isDone) Color.deepPlum else Color.driftGrey,
    animationSpec = bloom(),
    label = "crafting-row-text",
  )
  val state = stringResource(if (isDone) R.string.onboarding_step_done else R.string.onboarding_step_in_progress)

  Row(
    modifier = modifier
      .fillMaxWidth()
      .semantics(mergeDescendants = true) { stateDescription = state },
    horizontalArrangement = Arrangement.spacedBy(ROW_SPACING),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    AnimatedContent(
      targetState = isDone,
      transitionSpec = {
        (scaleIn(bloom(), initialScale = MARK_INITIAL_SCALE) + fadeIn(bloom())) togetherWith fadeOut(bloom())
      },
      label = "crafting-row-mark",
    ) { done ->
      if (done) FilledCheckMark() else HollowMark(alpha = RING_ALPHA)
    }

    Text(text = title, style = DeepType.body, color = textColor)
  }
}

@Preview(showBackground = true, name = "Crafting checklist row")
@Composable
private fun CraftingChecklistRowPreview() {
  OnboardingPreviewBackdrop {
    Column(
      modifier = Modifier.padding(horizontal = Dp.edge, vertical = Dp.rhythm),
      verticalArrangement = Arrangement.spacedBy(Dp.rhythm),
    ) {
      CraftingChecklistRow(title = "Gathering a little calm", isDone = true)
      CraftingChecklistRow(title = "Listening to what you shared", isDone = true)
      CraftingChecklistRow(title = "Shaping your space", isDone = false)
    }
  }
}
