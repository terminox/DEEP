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
import io.appbeyond.freelance.deep.feature.onboarding.store.AccountStore
import io.appbeyond.freelance.deep.feature.onboarding.store.MockAccountStore
import io.appbeyond.freelance.deep.feature.onboarding.store.MockOnboardingProgressStore
import io.appbeyond.freelance.deep.feature.onboarding.store.OnboardingProgressStore
import io.appbeyond.freelance.deep.feature.profile.SettingsScreen
import io.appbeyond.freelance.deep.feature.profile.YouScreen
import io.appbeyond.freelance.deep.shared.localization.AppLanguage
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.exhale

/**
 * Where a tab can go. One sealed hierarchy per tab would be tidier once the tabs
 * have depth; for now only You has a destination beyond its root, so they
 * share this.
 */
sealed interface DeepRoute {
  data object Root : DeepRoute

  /**
   * The system settings, pushed onto the You tab's stack. iOS's
   * `YouCoordinatorView` also routes `.language` and `.dailyReminder` from
   * here; on Android those rows are UI only for now, so they have no route.
   */
  data object Settings : DeepRoute
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
 *
 * All of its state — the selected tab and every stack — lives only as long as
 * it is composed. `AppRoot` drops it when the phase leaves Main (log out,
 * delete account) and composes a fresh one on the way back, so the next member
 * never opens on the last one's Settings screen.
 *
 * @param accountStore / onboardingStore the shared stores Settings writes to on
 *   the way out; flipping them is what moves `AppRoot` off this shell.
 * @param language the language Deep reads in, shown on Settings' Language row.
 */
@Composable
fun MainShellCoordinator(
  accountStore: AccountStore,
  onboardingStore: OnboardingProgressStore,
  language: AppLanguage,
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
            DeepTab.You -> YouScreen(
              accountStore = accountStore,
              onOpenSettings = { stacks.getValue(DeepTab.You).add(DeepRoute.Settings) },
            )
          }

          DeepRoute.Settings -> SettingsScreen(
            accountStore = accountStore,
            onboardingStore = onboardingStore,
            language = language,
            onBack = {
              val you = stacks.getValue(DeepTab.You)
              if (you.size > 1) you.removeAt(you.lastIndex)
            },
          )
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
    MainShellCoordinator(
      accountStore = MockAccountStore.emailUser,
      onboardingStore = MockOnboardingProgressStore.fresh,
      language = AppLanguage.English,
      homeContent = { TabPlaceholderScreen(DeepTab.Home) },
    )
  }
}
