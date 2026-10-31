package io.appbeyond.freelance.deep.feature.mindgarden

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.feature.mindgarden.components.PlantPickerSheet
import io.appbeyond.freelance.deep.feature.mindgarden.model.Plant
import io.appbeyond.freelance.deep.feature.mindgarden.store.GardenStore
import io.appbeyond.freelance.deep.feature.premium.PaywallScreen
import io.appbeyond.freelance.deep.feature.premium.model.PaywallSource
import io.appbeyond.freelance.deep.feature.rewards.store.MockRewardsRemote
import io.appbeyond.freelance.deep.shared.persistence.InMemoryBlobStore
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.card
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.exhale
import io.appbeyond.freelance.deep.theme.moonCream
import kotlinx.coroutines.launch

/** The saved-state key the plants keep while the invitation stands over them. */
private const val PICKER_KEY = "plant-picker"

/**
 * The plant picker sheet's coordinator — the composition root of the one flow
 * that lives inside it: choosing a plant, and, when the plant tapped is DEEP
 * Premium, the invitation.
 *
 * Ported from Deep/Deep/Features/MindGarden/PlantPickerCoordinatorView.swift.
 * The picker is a sheet, so the paywall can't be pushed on the Garden's own
 * stack — it would open *under* the sheet. It stands on this one instead,
 * inside the sheet, so it appears over the plants and "Not right now" — or
 * system back, or a finished purchase — steps straight back to them. The
 * sheet grows to full height for it, since the paywall is a screen, not a
 * card, and settles back to the plants' own height after.
 *
 * Per the project's rules this carries no styling beyond the sheet's frame;
 * the picker and the paywall each draw their own atmosphere. The plants keep
 * their saved state ([rememberSaveableStateHolder]) while covered, so a staged
 * choice is still staged on the way back.
 *
 * @param garden the store the picker reads and switches through.
 * @param onDismiss the sheet has gone — swiped away, kept, or switched.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PlantPickerCoordinator(
  garden: GardenStore,
  onDismiss: () -> Unit,
) {
  val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
  val scope = rememberCoroutineScope()
  val screens = rememberSaveableStateHolder()
  // The invitation standing over the plants, and the door it was opened by.
  var paywall by rememberSaveable { mutableStateOf<PaywallSource?>(null) }

  fun close() {
    scope.launch {
      sheetState.hide()
      onDismiss()
    }
  }

  ModalBottomSheet(
    onDismissRequest = onDismiss,
    sheetState = sheetState,
    shape = RoundedCornerShape(topStart = Dp.card, topEnd = Dp.card),
    containerColor = Color.moonCream,
    contentColor = Color.deepPlum,
    tonalElevation = 0.dp,
    dragHandle = null,
  ) {
    // Back steps off the invitation first; only from the plants does it
    // dismiss the sheet.
    BackHandler(enabled = paywall != null) { paywall = null }

    AnimatedContent(
      targetState = paywall,
      transitionSpec = { fadeIn(exhale()) togetherWith fadeOut(exhale()) },
      label = "plant-picker-route",
    ) { source ->
      if (source == null) {
        screens.SaveableStateProvider(PICKER_KEY) {
          PlantPickerSheet(
            garden = garden,
            onClose = ::close,
            onOpenPaywall = { opened -> if (paywall == null) paywall = opened },
          )
        }
      } else {
        PaywallScreen(
          source = source,
          onFinish = { paywall = null },
          modifier = Modifier.fillMaxSize(),
        )
      }
    }
  }
}

/** The real sheet over a mock garden with a premium plant — run it in interactive mode. */
@Preview(showBackground = true, name = "Plant picker — sheet (interactive)")
@Composable
private fun PlantPickerCoordinatorPreview() {
  val tallies = mapOf("oak" to 240, "sakura" to 160, "lotus" to 0, "moonflower" to 360)
  val garden = remember {
    GardenStore(remote = MockRewardsRemote(sunlightByPlant = tallies), blob = InMemoryBlobStore())
      .apply { seed(Plant.oakFixture, sunlight = 240, sunlightByPlant = tallies) }
  }
  DeepTheme { PlantPickerCoordinator(garden = garden, onDismiss = {}) }
}
