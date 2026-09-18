package io.appbeyond.freelance.deep.feature.appshell

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshots.SnapshotStateList
import androidx.compose.runtime.toMutableStateList
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import io.appbeyond.freelance.deep.feature.deepsession.model.DeepSession
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.exhale

/**
 * Where a tab can go. One sealed hierarchy per tab would be tidier once the tabs
 * have depth; in week one only Home has a destination beyond its root, so they
 * share this.
 */
sealed interface DeepRoute {
  data object Root : DeepRoute
}

/**
 * The tab shell: five tabs, each with **its own back stack**, over one bottom bar.
 *
 * This is the coordinator the project's rules describe — it owns navigation and
 * nothing else, and the leaf screens it routes to never host a container of their
 * own. They receive navigation as actions, passed down as plain lambdas so a
 * `@Preview` of a leaf stays hermetic.
 *
 * Styling deliberately stays out of here. Each leaf paints its own atmosphere;
 * a background placed at this level would sit behind the bar and never be seen,
 * which is a mistake the iOS side already made once and documented.
 */
@Composable
fun MainShellCoordinator(
  modifier: Modifier = Modifier,
  onOpenDeepSession: (DeepSession) -> Unit = {},
  homeContent: @Composable (onOpenDeepSession: (DeepSession) -> Unit) -> Unit = {},
) {
  var selected by rememberSaveable { mutableStateOf(DeepTab.Home) }

  // One stack per tab, so switching away and back returns you where you were —
  // and so system back unwinds the tab you are actually looking at.
  val stacks: Map<DeepTab, SnapshotStateList<DeepRoute>> = remember {
    DeepTab.entries.associateWith { listOf<DeepRoute>(DeepRoute.Root).toMutableStateList() }
  }
  val stack = stacks.getValue(selected)

  // Back unwinds the active tab, then falls back to Home, and only then leaves
  // the app. Anything else strands someone three tabs deep.
  BackHandler(enabled = stack.size > 1 || selected != DeepTab.Home) {
    if (stack.size > 1) stack.removeAt(stack.lastIndex) else selected = DeepTab.Home
  }

  Column(modifier.fillMaxSize()) {
    Box(Modifier.weight(1f)) {
      AnimatedContent(
        targetState = selected to stack.last(),
        transitionSpec = { fadeIn(exhale()) togetherWith fadeOut(exhale()) },
        label = "tab-content",
      ) { (tab, route) ->
        when (route) {
          DeepRoute.Root -> when (tab) {
            DeepTab.Home -> homeContent(onOpenDeepSession)
            DeepTab.Sounds -> TabPlaceholderScreen(DeepTab.Sounds)
            DeepTab.Garden -> TabPlaceholderScreen(DeepTab.Garden)
            DeepTab.Compassion -> TabPlaceholderScreen(DeepTab.Compassion)
            DeepTab.You -> TabPlaceholderScreen(DeepTab.You)
          }
        }
      }
    }

    DeepBottomBar(
      selected = selected,
      onSelect = { tab ->
        // Re-tapping the tab you are on pops it to root, the way it does on iOS.
        if (tab == selected) {
          while (stack.size > 1) stack.removeAt(stack.lastIndex)
        } else {
          selected = tab
        }
      },
    )
  }
}

@Preview(showBackground = true)
@Composable
private fun MainShellCoordinatorPreview() {
  DeepTheme {
    MainShellCoordinator(homeContent = { TabPlaceholderScreen(DeepTab.Home) })
  }
}
