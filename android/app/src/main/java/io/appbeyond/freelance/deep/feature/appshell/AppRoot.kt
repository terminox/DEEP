package io.appbeyond.freelance.deep.feature.appshell

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.tooling.preview.Preview
import io.appbeyond.freelance.deep.feature.deepsession.model.DeepSession
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.BreatheLoadingView
import io.appbeyond.freelance.deep.theme.BREATHE_FLOOR_MILLIS
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.hush
import io.appbeyond.freelance.deep.theme.moonCream
import kotlinx.coroutines.delay

/**
 * The app's composition root and phase machine.
 *
 * iOS decides among three phases — restoring, the onboarding flow, and the main
 * shell. `v0.0.1` has two: onboarding and accounts land in week 2, so a launch
 * goes straight from the breathing beat into the shell.
 *
 * One moonCream and atmosphere backdrop persists beneath every phase, so
 * hand-offs crossfade atmosphere to atmosphere and never dip to white.
 *
 * The launch beat holds for [BREATHE_FLOOR_MILLIS] even when there is nothing to
 * wait for. That floor is the point: a fast start that flashes a loading state
 * for 80ms is worse than one that breathes once, and this app is about arriving
 * somewhere calmly rather than arriving fastest.
 */
@Composable
fun AppRoot(
  modifier: Modifier = Modifier,
  homeContent: @Composable (onOpenDeepSession: (DeepSession) -> Unit) -> Unit = {},
  deepSessionContent: @Composable (session: DeepSession, onFinish: () -> Unit) -> Unit =
    { _, _ -> },
) {
  var restored by remember { mutableStateOf(false) }

  // Week 2 replaces the bare floor with the real session restore, which awaits
  // both the backend and this floor.
  LaunchedEffect(Unit) {
    delay(BREATHE_FLOOR_MILLIS)
    restored = true
  }

  // Owned here, above the shell, for the reason the iOS side owns its chime
  // outside the presentation: the practice's closing bell rings for several
  // seconds and has to outlive the screen being dismissed.
  var runningSession by remember { mutableStateOf<DeepSession?>(null) }

  DeepTheme {
    Box(modifier.fillMaxSize().background(Color.moonCream)) {
      // The one persistent backdrop. It rests while the opaque shell covers it,
      // so the drift costs nothing per frame once you are in the app.
      AtmosphereBackground(animated = !restored)

      AnimatedVisibility(visible = restored, enter = fadeIn(hush()), exit = fadeOut(hush())) {
        MainShellCoordinator(
          homeContent = homeContent,
          onOpenDeepSession = { runningSession = it },
        )
      }

      AnimatedVisibility(
        visible = !restored,
        enter = fadeIn(hush()),
        exit = fadeOut(hush()),
      ) {
        // No backdrop of its own: the persistent moonCream and atmosphere above
        // are already drawn, and a second one would double the wash.
        BreatheLoadingView(drawsBackdrop = false)
      }

      // The practice presents over the whole shell, tab bar included — which on
      // Android is simply a sibling in the same tree. The iOS equivalent needs a
      // zero-size UIViewControllerRepresentable that walks up the controller
      // hierarchy to find something able to present; none of that exists here.
      val session = runningSession
      AnimatedVisibility(
        visible = session != null,
        enter = fadeIn(hush()) + slideInVertically(hush()) { it / 24 },
        exit = fadeOut(hush()),
      ) {
        if (session != null) {
          deepSessionContent(session) { runningSession = null }
        }
      }
    }
  }
}

@Preview(showBackground = true)
@Composable
private fun AppRootPreview() {
  AppRoot(homeContent = { TabPlaceholderScreen(DeepTab.Home) })
}
