package io.appbeyond.freelance.deep

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.appbeyond.freelance.deep.feature.appshell.AppRoot
import io.appbeyond.freelance.deep.feature.deepsession.DeepSessionCoordinator
import io.appbeyond.freelance.deep.feature.globalpause.GlobalPauseHomeScreen

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
        homeContent = { onOpenDeepSession ->
          GlobalPauseHomeScreen(
            repository = dependencies.pauseHome,
            onOpenDeepSession = onOpenDeepSession,
          )
        },
        deepSessionContent = { session, onFinish ->
          DeepSessionCoordinator(session = session, onFinish = onFinish)
        },
      )
    }
  }
}
