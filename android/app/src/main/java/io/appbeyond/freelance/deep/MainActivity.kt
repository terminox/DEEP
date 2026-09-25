package io.appbeyond.freelance.deep

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.appbeyond.freelance.deep.feature.appshell.AppRoot
import io.appbeyond.freelance.deep.feature.deepsession.DeepSessionCoordinator
import io.appbeyond.freelance.deep.feature.globalpause.GlobalPauseHomeScreen
import io.appbeyond.freelance.deep.feature.onboarding.OnboardingCoordinator

/**
 * The single activity. Everything above this is Compose.
 *
 * Portrait-only and light-only, matching iOS — there is no dark palette to fall
 * back to, so a dark window would show through the atmosphere.
 *
 * Dependencies are read from the application's one composition root rather than
 * resolved from a graph, which is what keeps every screen previewable: each takes
 * what it needs as a parameter and a preview hands it a stub.
 */
class MainActivity : ComponentActivity() {

  override fun onCreate(savedInstanceState: Bundle?) {
    installSplashScreen()
    enableEdgeToEdge()
    super.onCreate(savedInstanceState)

    val dependencies = (application as DeepApplication).dependencies

    setContent {
      AppRoot(
        accountStore = dependencies.accountStore,
        onboardingStore = dependencies.onboardingStore,
        onboardingRemote = dependencies.onboardingRemote,
        awaitOnboardingLoaded = dependencies::awaitOnboardingLoaded,
        language = dependencies.language,
        flowContent = {
          OnboardingCoordinator(
            accountStore = dependencies.accountStore,
            onboardingStore = dependencies.onboardingStore,
            remote = dependencies.onboardingRemote,
          )
        },
        homeContent = { onOpenDeepSession ->
          // Keyed on the member, so the personalised "Made for you" shelf
          // reloads for whoever just signed up or logged in rather than
          // keeping the feed fetched before their token existed.
          val account by dependencies.accountStore.account.collectAsStateWithLifecycle()
          GlobalPauseHomeScreen(
            repository = dependencies.pauseHome,
            onOpenDeepSession = onOpenDeepSession,
            refreshKey = account?.id,
          )
        },
        deepSessionContent = { session, onFinish ->
          DeepSessionCoordinator(session = session, onFinish = onFinish)
        },
      )
    }
  }
}
