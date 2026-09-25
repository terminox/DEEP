package io.appbeyond.freelance.deep.feature.onboarding.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.onboarding.components.BLOOM_ROOM
import io.appbeyond.freelance.deep.feature.onboarding.components.OnboardingPreviewBackdrop
import io.appbeyond.freelance.deep.feature.onboarding.components.OnboardingPrimaryButton
import io.appbeyond.freelance.deep.feature.onboarding.components.QuizOptionCard
import io.appbeyond.freelance.deep.feature.onboarding.components.bloomBleed
import io.appbeyond.freelance.deep.feature.onboarding.components.onboardingContentDrift
import io.appbeyond.freelance.deep.feature.onboarding.store.MockOnboardingProgressStore
import io.appbeyond.freelance.deep.feature.onboarding.store.OnboardingProgressStore
import io.appbeyond.freelance.deep.feature.onboarding.store.fixture
import io.appbeyond.freelance.deep.onboarding.model.OnboardingConfig
import io.appbeyond.freelance.deep.onboarding.model.OnboardingRoute
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.rhythm
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.launch

private val OPTION_SPACING = 14.dp

/**
 * One single-select quiz question. Reads its question from the loaded config by
 * [index] and records the choice as it is made; Continue advances to the next
 * question, or to the Mind Tree picker after the last. The progress bar lives
 * in the coordinator's chrome, not here.
 *
 * Ported from Deep/Deep/Features/Onboarding/Screens/OnboardingQuizView.swift.
 * A missing question renders nothing: the coordinator holds the quiz route
 * until the config has loaded, so that is a guard, not a designed state.
 */
@Composable
fun QuizScreen(
  index: Int,
  config: OnboardingConfig,
  onboardingStore: OnboardingProgressStore,
  onAdvance: (OnboardingRoute) -> Unit,
  modifier: Modifier = Modifier,
) {
  val question = config.questions.getOrNull(index) ?: return
  val isLast = index == config.questions.lastIndex
  val scope = rememberCoroutineScope()
  var selectedOptionId by remember(question.id) {
    mutableStateOf(onboardingStore.state.value.quizAnswers[question.id])
  }

  Column(
    modifier = modifier
      .fillMaxSize()
      .safeDrawingPadding()
      .padding(horizontal = Dp.edge)
      .padding(bottom = Dp.rhythm),
    verticalArrangement = Arrangement.spacedBy(Dp.rhythm),
  ) {
    Column(
      modifier = Modifier
        .weight(1f)
        .onboardingContentDrift(),
      verticalArrangement = Arrangement.spacedBy(Dp.rhythm - BLOOM_ROOM),
    ) {
      Text(text = question.prompt, style = DeepType.displayTitle, color = Color.deepPlum)

      LazyColumn(
        modifier = Modifier
          .fillMaxWidth()
          .bloomBleed(),
        contentPadding = PaddingValues(BLOOM_ROOM),
        verticalArrangement = Arrangement.spacedBy(OPTION_SPACING),
      ) {
        items(question.options, key = { it.id }) { option ->
          QuizOptionCard(
            option = option,
            isSelected = selectedOptionId == option.id,
            onClick = {
              selectedOptionId = option.id
              // Undispatched, so the store's in-memory write lands inside this
              // click: a Continue in the same frame disposes [scope], and a
              // coroutine cancelled before its first dispatch never runs. The
              // disk write then rides the store's own scope.
              scope.launch(start = CoroutineStart.UNDISPATCHED) {
                onboardingStore.recordAnswer(question.id, option.id)
              }
            },
          )
        }
      }
    }

    OnboardingPrimaryButton(
      title = stringResource(R.string.onboarding_continue),
      enabled = selectedOptionId != null,
      onClick = {
        onAdvance(if (isLast) OnboardingRoute.MindTree else OnboardingRoute.Quiz(index + 1))
      },
    )
  }
}

@Preview(showBackground = true, name = "Quiz")
@Composable
private fun QuizScreenPreview() {
  OnboardingPreviewBackdrop {
    QuizScreen(
      index = 0,
      config = OnboardingConfig.fixture,
      onboardingStore = MockOnboardingProgressStore.midQuiz,
      onAdvance = {},
    )
  }
}
