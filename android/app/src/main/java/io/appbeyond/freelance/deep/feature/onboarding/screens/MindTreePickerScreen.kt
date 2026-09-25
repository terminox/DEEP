package io.appbeyond.freelance.deep.feature.onboarding.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
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
import io.appbeyond.freelance.deep.feature.onboarding.components.MindTreeCard
import io.appbeyond.freelance.deep.feature.onboarding.components.OnboardingPreviewBackdrop
import io.appbeyond.freelance.deep.feature.onboarding.components.OnboardingPrimaryButton
import io.appbeyond.freelance.deep.feature.onboarding.components.bloomBleed
import io.appbeyond.freelance.deep.feature.onboarding.components.onboardingContentDrift
import io.appbeyond.freelance.deep.feature.onboarding.store.MockOnboardingProgressStore
import io.appbeyond.freelance.deep.feature.onboarding.store.OnboardingProgressStore
import io.appbeyond.freelance.deep.feature.onboarding.store.fixture
import io.appbeyond.freelance.deep.onboarding.model.OnboardingConfig
import io.appbeyond.freelance.deep.onboarding.model.OnboardingRoute
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.rhythm
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.launch

private val GRID_SPACING = 14.dp
private val HEADER_SPACING = 6.dp

/**
 * The flow's final choice: pick a Mind Tree. The trees come from the loaded
 * config — the published, non-premium default plants of the admin-managed
 * catalog — and the pick is recorded as it is made, seeding the Mind Garden's
 * selection when onboarding is saved.
 *
 * Ported from Deep/Deep/Features/Onboarding/Screens/MindTreePickerView.swift.
 */
@Composable
fun MindTreePickerScreen(
  config: OnboardingConfig,
  onboardingStore: OnboardingProgressStore,
  onAdvance: (OnboardingRoute) -> Unit,
  modifier: Modifier = Modifier,
) {
  val scope = rememberCoroutineScope()
  var selectedTreeId by remember { mutableStateOf(onboardingStore.state.value.mindTree) }

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
      Column(verticalArrangement = Arrangement.spacedBy(HEADER_SPACING)) {
        Text(
          text = stringResource(R.string.onboarding_mind_tree_title),
          style = DeepType.displayTitle,
          color = Color.deepPlum,
        )
        Text(
          text = stringResource(R.string.onboarding_mind_tree_subtitle),
          style = DeepType.caption,
          color = Color.driftGrey,
        )
      }

      LazyVerticalGrid(
        columns = GridCells.Fixed(2),
        modifier = Modifier
          .fillMaxWidth()
          .bloomBleed(),
        contentPadding = PaddingValues(BLOOM_ROOM),
        horizontalArrangement = Arrangement.spacedBy(GRID_SPACING),
        verticalArrangement = Arrangement.spacedBy(GRID_SPACING),
      ) {
        items(config.mindTrees, key = { it.id }) { tree ->
          MindTreeCard(
            tree = tree,
            isSelected = selectedTreeId == tree.id,
            onClick = {
              selectedTreeId = tree.id
              // Recorded now, inside this click (undispatched, so a Continue
              // that disposes [scope] this frame can't drop it); the disk
              // write rides the store's own scope. The Mind Garden reads it later.
              scope.launch(start = CoroutineStart.UNDISPATCHED) {
                onboardingStore.recordMindTree(tree.id)
              }
            },
          )
        }
      }
    }

    OnboardingPrimaryButton(
      title = stringResource(R.string.onboarding_continue),
      enabled = selectedTreeId != null,
      onClick = { onAdvance(OnboardingRoute.CreateAccount) },
    )
  }
}

@Preview(showBackground = true, name = "Mind Tree")
@Composable
private fun MindTreePickerScreenPreview() {
  OnboardingPreviewBackdrop {
    MindTreePickerScreen(
      config = OnboardingConfig.fixture,
      onboardingStore = MockOnboardingProgressStore.fresh,
      onAdvance = {},
    )
  }
}
