package io.appbeyond.freelance.deep.feature.onboarding.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.onboarding.components.CraftingChecklistRow
import io.appbeyond.freelance.deep.feature.onboarding.components.OnboardingPreviewBackdrop
import io.appbeyond.freelance.deep.feature.onboarding.components.onboardingContentDrift
import io.appbeyond.freelance.deep.feature.onboarding.store.MockOnboardingProgressStore
import io.appbeyond.freelance.deep.feature.onboarding.store.MockOnboardingRemote
import io.appbeyond.freelance.deep.feature.onboarding.store.OnboardingProgressStore
import io.appbeyond.freelance.deep.feature.onboarding.store.OnboardingRemote
import io.appbeyond.freelance.deep.onboarding.model.CraftingTiming
import io.appbeyond.freelance.deep.shared.components.rememberReduceMotion
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.rhythm
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.ensureActive

private val TITLE_TOP = 8.dp
private val STEP_SPACING = 20.dp

/**
 * A gentle loading beat once the account exists: a short checklist ticks itself
 * off, the gathered answers are saved to the server, and onboarding finishes —
 * the root then crossfades into the app. No percentage, no urgency.
 *
 * Ported from Deep/Deep/Features/Onboarding/Screens/CraftingSpaceView.swift,
 * timings from [CraftingTiming].
 *
 * The save is best-effort: if the network is down onboarding still completes
 * locally so nobody is stranded. Cancellation is not a network failure, though
 * — if this screen leaves mid-beat its effect is cancelled, and completing
 * anyway would open the gate without the sync. So a cancelled run simply
 * stops, before and after the save.
 */
@Composable
fun CraftingSpaceScreen(
  onboardingStore: OnboardingProgressStore,
  remote: OnboardingRemote,
  modifier: Modifier = Modifier,
) {
  val reduceMotion = rememberReduceMotion()
  var completedCount by remember { mutableIntStateOf(0) }
  val steps = listOf(
    stringResource(R.string.onboarding_crafting_step_1),
    stringResource(R.string.onboarding_crafting_step_2),
    stringResource(R.string.onboarding_crafting_step_3),
    stringResource(R.string.onboarding_crafting_step_4),
    stringResource(R.string.onboarding_crafting_step_5),
  )

  LaunchedEffect(Unit) {
    val stepMillis = if (reduceMotion) CraftingTiming.STEP_MILLIS_REDUCED_MOTION else CraftingTiming.STEP_MILLIS
    for (step in 1..CraftingTiming.STEP_COUNT) {
      delay(stepMillis)
      completedCount = step
    }
    delay(CraftingTiming.SETTLE_MILLIS)

    try {
      // Read now, at submit time, not captured when the beat began: the store
      // updates `state` synchronously, so this is every answer given.
      remote.submit(onboardingStore.state.value.completed())
    } catch (e: CancellationException) {
      throw e
    } catch (e: Exception) {
      // Best-effort: the answers are persisted locally either way.
    }
    ensureActive()
    onboardingStore.completeOnboarding()
  }

  Column(
    modifier = modifier
      .fillMaxSize()
      .safeDrawingPadding()
      .padding(horizontal = Dp.edge)
      .padding(bottom = Dp.rhythm)
      .onboardingContentDrift(),
    verticalArrangement = Arrangement.spacedBy(Dp.rhythm),
  ) {
    Text(
      text = stringResource(R.string.onboarding_crafting_title),
      style = DeepType.displayTitle,
      color = Color.deepPlum,
      modifier = Modifier.padding(top = TITLE_TOP),
    )

    Column(verticalArrangement = Arrangement.spacedBy(STEP_SPACING)) {
      steps.forEachIndexed { offset, step ->
        CraftingChecklistRow(title = step, isDone = offset < completedCount)
      }
    }
  }
}

@Preview(showBackground = true, name = "Crafting")
@Composable
private fun CraftingSpaceScreenPreview() {
  OnboardingPreviewBackdrop {
    CraftingSpaceScreen(
      onboardingStore = MockOnboardingProgressStore.midQuiz,
      remote = MockOnboardingRemote(),
    )
  }
}
