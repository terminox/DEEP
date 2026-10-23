package io.appbeyond.freelance.deep.feature.onboarding.screens

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.tooling.preview.Preview
import io.appbeyond.freelance.deep.feature.onboarding.components.OnboardingPreviewBackdrop
import io.appbeyond.freelance.deep.networking.DeepApiException
import io.appbeyond.freelance.deep.shared.components.BreatheLoadingView
import io.appbeyond.freelance.deep.theme.BREATHE_FLOOR_MILLIS
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.exhale
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay

/**
 * Runs [block] while holding the breathing beat for at least
 * [BREATHE_FLOOR_MILLIS], however fast the network answers — a flash of it
 * reads as a glitch, not a breath. The floor is awaited on failure too, so an
 * error never snaps in under a beat that has only just appeared.
 *
 * The twin of iOS's `async let floor = Task.sleep(for: .breatheFloor)` in
 * `SignUpView` / `LogInView`. Cancellation passes straight through.
 */
internal suspend fun <T> heldForBreatheFloor(block: suspend () -> T): T = coroutineScope {
  val floor = async { delay(BREATHE_FLOOR_MILLIS) }
  val outcome = try {
    Result.success(block())
  } catch (e: CancellationException) {
    throw e
  } catch (e: Exception) {
    Result.failure(e)
  }
  floor.await()
  outcome.getOrThrow()
}

/** The copy to show for a failure: the server's own sentence when there is one, else [fallback]. */
internal fun Throwable.displayMessage(fallback: String): String =
  (this as? DeepApiException)?.message ?: fallback

/**
 * The full-screen breathing beat an auth screen raises while it talks to the
 * server. Opaque (it draws its own backdrop, as on iOS) and it swallows every
 * touch, so the form beneath can't be edited or resubmitted mid-request.
 */
@Composable
internal fun AuthBreatheOverlay(visible: Boolean, line: String, modifier: Modifier = Modifier) {
  AnimatedVisibility(
    visible = visible,
    enter = fadeIn(exhale()),
    exit = fadeOut(exhale()),
    modifier = modifier,
  ) {
    BreatheLoadingView(
      line = line,
      modifier = Modifier
        .fillMaxSize()
        .pointerInput(Unit) {
          awaitEachGesture { awaitFirstDown(requireUnconsumed = false).consume() }
        },
    )
  }
}

/**
 * Holds an auth screen in place while its request is in flight. The breathe
 * overlay only swallows touches; system and predictive back would still pop
 * the screen, disposing its scope and cancelling the request — possibly after
 * the server already created the account (a retry then meets `email_taken`)
 * or after it was adopted (sending a signed-in member back to the gate).
 *
 * So while [submitting] this consumes back outright. It is composed inside
 * the routed screen, after the coordinator's own handlers, and the
 * most-recently-registered enabled handler wins, so it pre-empts the
 * coordinator's pop. It also reports [submitting] to the coordinator through
 * [onSubmittingChange], which hides the floating chrome — its back button
 * sits above this screen's overlay — and resets to false if the screen leaves.
 */
@Composable
internal fun AuthRequestGuard(submitting: Boolean, onSubmittingChange: (Boolean) -> Unit) {
  BackHandler(enabled = submitting) {}
  val report by rememberUpdatedState(onSubmittingChange)
  SideEffect { report(submitting) }
  DisposableEffect(Unit) {
    onDispose { report(false) }
  }
}

@Preview(showBackground = true, name = "Auth breathe overlay")
@Composable
private fun AuthBreatheOverlayPreview() {
  OnboardingPreviewBackdrop {
    Text("Form beneath", style = DeepType.body, color = Color.deepPlum)
    AuthBreatheOverlay(visible = true, line = "Take a deep breath.\nWe're signing you in.")
  }
}
