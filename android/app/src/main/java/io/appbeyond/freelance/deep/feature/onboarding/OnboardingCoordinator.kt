package io.appbeyond.freelance.deep.feature.onboarding

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.onboarding.components.LocalOnboardingContentDrift
import io.appbeyond.freelance.deep.feature.onboarding.components.OnboardingChromeBar
import io.appbeyond.freelance.deep.feature.onboarding.components.OnboardingChromeHeight
import io.appbeyond.freelance.deep.feature.onboarding.screens.CraftingSpaceScreen
import io.appbeyond.freelance.deep.feature.onboarding.screens.CreateAccountScreen
import io.appbeyond.freelance.deep.feature.onboarding.screens.LogInScreen
import io.appbeyond.freelance.deep.feature.onboarding.screens.MindTreePickerScreen
import io.appbeyond.freelance.deep.feature.onboarding.screens.QuizScreen
import io.appbeyond.freelance.deep.feature.onboarding.screens.SignUpScreen
import io.appbeyond.freelance.deep.feature.onboarding.screens.WelcomeConfigState
import io.appbeyond.freelance.deep.feature.onboarding.screens.WelcomeScreen
import io.appbeyond.freelance.deep.feature.onboarding.screens.WelcomeVideo
import io.appbeyond.freelance.deep.feature.onboarding.store.AccountStore
import io.appbeyond.freelance.deep.feature.onboarding.store.MockAccountStore
import io.appbeyond.freelance.deep.feature.onboarding.store.MockOnboardingProgressStore
import io.appbeyond.freelance.deep.feature.onboarding.store.MockOnboardingRemote
import io.appbeyond.freelance.deep.feature.onboarding.store.OnboardingProgressStore
import io.appbeyond.freelance.deep.feature.onboarding.store.OnboardingRemote
import io.appbeyond.freelance.deep.feature.onboarding.transition.RippleRevealOverlay
import io.appbeyond.freelance.deep.onboarding.model.ConfigRetryDelaysMillis
import io.appbeyond.freelance.deep.onboarding.model.NavDirection
import io.appbeyond.freelance.deep.onboarding.model.OnboardingConfig
import io.appbeyond.freelance.deep.onboarding.model.OnboardingNav
import io.appbeyond.freelance.deep.onboarding.model.OnboardingNavigator
import io.appbeyond.freelance.deep.onboarding.model.OnboardingRoute
import io.appbeyond.freelance.deep.onboarding.model.onboardingProgress
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.LoopingVideoFrameGrabber
import io.appbeyond.freelance.deep.shared.components.rememberReduceMotion
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.drift
import io.appbeyond.freelance.deep.theme.hush
import io.appbeyond.freelance.deep.theme.moonCream
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay

/**
 * Composition root for the first-run onboarding flow.
 *
 * Ported from Deep/Deep/Features/Onboarding/OnboardingCoordinatorView.swift. It
 * owns the route stack ([OnboardingNav]; empty = the welcome screen) and every
 * change to it goes through [OnboardingNavigator] — this file decides *how* a
 * hand-off looks, never *where* it goes. Screens hand off with a calm [hush]
 * crossfade in place rather than a push, so fixed elements (footer CTAs) never
 * move, while each screen's content block drifts [Dp.drift] in the routing
 * direction via [LocalOnboardingContentDrift].
 *
 * The flow's content — quiz questions and Mind Trees — is server-driven, so
 * the coordinator also owns fetching it, with the [ConfigRetryDelaysMillis]
 * schedule (production Cloud Run scales to zero and its first request after an
 * idle spell routinely outlasts one short timeout). The welcome CTA waits on
 * that state and offers a retry when it fails; nothing falls back to bundled
 * content.
 *
 * Persistent chrome — the frosted back button and, on counted steps, the
 * progress bar — floats above the transitioning screens, so only what is
 * beneath it changes. Back (the chrome button, or system / predictive back,
 * which covers iOS's edge swipe) is a plain stack pop everywhere except the
 * crafting loader, which can't be backed out of, and an auth screen with a
 * request in flight, which holds back itself and hides the chrome meanwhile.
 * Those screens' handlers are composed inside [AnimatedContent], after the two
 * here, so as the most recently registered enabled handler theirs wins.
 *
 * Leaving the welcome screen gets a bespoke send-off: the destination replaces
 * it with no transition at all while a freeze-frame of the welcome screen
 * ripples away above it from the tapped point ([RippleRevealOverlay]). Reduced
 * motion falls back to the plain crossfade.
 *
 * Draws no atmosphere of its own: `AppRoot` keeps one persistent moonCream +
 * atmosphere under every phase, so hand-offs never dip to a half-transparent
 * background mid-crossfade. Finishing is `onboardingStore.completeOnboarding()`;
 * the root flips to Main by itself once signed in and completed.
 */
@Composable
fun OnboardingCoordinator(
  accountStore: AccountStore,
  onboardingStore: OnboardingProgressStore,
  remote: OnboardingRemote,
  modifier: Modifier = Modifier,
) {
  val reduceMotion = rememberReduceMotion()
  val account by accountStore.account.collectAsState()

  var nav by remember { mutableStateOf(OnboardingNav()) }
  var configLoad by remember { mutableStateOf<ConfigLoad>(ConfigLoad.Loading) }
  // Bumped to re-run the fetch; keys the effect below.
  var configAttempt by remember { mutableIntStateOf(0) }
  // Present while the welcome freeze-frame ripples away; null the rest of the time.
  var ripple by remember { mutableStateOf<RippleContext?>(null) }
  // True for the one hand-off the ripple covers, so it swaps with no fade or drift.
  var instantSwap by remember { mutableStateOf(false) }
  val frameGrabber = remember { LoopingVideoFrameGrabber() }
  val touch = remember { RippleTouchTracker() }
  // True while SignUp / LogIn has a request in flight. The chrome's back button
  // floats above their breathe overlay, so it is hidden and back is held until
  // the request settles (system back is consumed by the screen itself).
  var authInFlight by remember { mutableStateOf(false) }

  val config = (configLoad as? ConfigLoad.Loaded)?.config ?: OnboardingConfig.Empty
  val signedIn = account != null

  LaunchedEffect(configAttempt) {
    configLoad = ConfigLoad.Loading
    for (delayMillis in ConfigRetryDelaysMillis) {
      if (delayMillis > 0) delay(delayMillis)
      val fetched = try {
        remote.fetchConfig()
      } catch (e: CancellationException) {
        throw e
      } catch (e: Exception) {
        null
      }
      // A config with nothing to ask or pick would strand the member on a
      // blank quiz or picker, so it counts as a failure, not a success — and
      // fails at once: a server that answered won't answer differently in a
      // few seconds, so the retry schedule is only for not answering.
      if (fetched != null && !fetched.isUsable()) break
      if (fetched != null) {
        configLoad = ConfigLoad.Loaded(fetched)
        // Replays a quiz route asked for before the config landed (the
        // post-login resume is the only way to get here).
        val replayed = OnboardingNavigator.configLoaded(nav, signedIn = accountStore.account.value != null)
        if (replayed != nav) {
          instantSwap = false
          nav = replayed
        }
        return@LaunchedEffect
      }
    }
    configLoad = ConfigLoad.Failed
  }

  fun retryConfig() {
    configAttempt += 1
  }

  fun advance(route: OnboardingRoute) {
    val loaded = configLoad is ConfigLoad.Loaded
    val next = OnboardingNavigator.advance(nav, route, configLoaded = loaded, signedIn = signedIn)
    if (route is OnboardingRoute.Quiz && !loaded) {
      // Held until the config lands; a failed fetch gets another go.
      nav = next
      if (configLoad is ConfigLoad.Failed) retryConfig()
      return
    }
    if (next == nav) return

    val leavingWelcome = nav.stack.isEmpty()
    if (leavingWelcome && !reduceMotion && ripple == null) {
      ripple = RippleContext(
        still = frameGrabber.currentFrame()?.asImageBitmap(),
        origin = touch.origin(),
      )
      instantSwap = true
    } else {
      instantSwap = false
    }
    nav = next
  }

  fun goBack() {
    if (authInFlight) return
    val next = OnboardingNavigator.back(nav)
    if (next == nav) return
    instantSwap = false
    nav = next
  }

  BackHandler(enabled = nav.stack.isNotEmpty() && nav.current != OnboardingRoute.CraftingSpace) { goBack() }
  // The crafting loader is committing the gathered answers: back is held
  // rather than letting it fall through and close the app mid-save.
  BackHandler(enabled = nav.current == OnboardingRoute.CraftingSpace) {}

  val density = LocalDensity.current
  val driftPx = with(density) { Dp.drift.roundToPx() }

  Box(
    modifier
      .fillMaxSize()
      .onGloballyPositioned { touch.coordinates = it }
      // Only listens, in the initial pass and without consuming, to learn
      // where a tap landed so the ripple can emanate from it.
      .pointerInput(Unit) {
        awaitEachGesture {
          val down = awaitFirstDown(requireUnconsumed = false, pass = PointerEventPass.Initial)
          touch.location = touch.coordinates?.takeIf { it.isAttached }?.localToWindow(down.position)
        }
      },
  ) {
    AnimatedContent(
      targetState = nav.current,
      transitionSpec = {
        if (initialState == null && instantSwap) {
          EnterTransition.None togetherWith ExitTransition.None
        } else {
          fadeIn(hush()) togetherWith fadeOut(hush())
        }
      },
      label = "onboarding-screen",
    ) { route ->
      val forward = nav.direction == NavDirection.Forward
      val drift = if (reduceMotion || instantSwap) {
        Modifier
      } else {
        Modifier.animateEnterExit(
          enter = slideInVertically(hush()) { if (forward) driftPx else -driftPx },
          exit = slideOutVertically(hush()) { if (forward) -driftPx else driftPx },
        )
      }

      CompositionLocalProvider(LocalOnboardingContentDrift provides drift) {
        when (route) {
          null -> WelcomeScreen(
            configState = when (configLoad) {
              ConfigLoad.Loading -> WelcomeConfigState.Loading
              is ConfigLoad.Loaded -> WelcomeConfigState.Ready
              ConfigLoad.Failed -> WelcomeConfigState.Failed
            },
            onBegin = { advance(OnboardingRoute.Quiz(0)) },
            onLogIn = { advance(OnboardingRoute.LogIn) },
            onRetry = ::retryConfig,
            video = WelcomeVideo.Live(frameGrabber),
          )

          is OnboardingRoute.Quiz -> Routed {
            QuizScreen(
              index = route.index,
              config = config,
              onboardingStore = onboardingStore,
              onAdvance = ::advance,
            )
          }

          OnboardingRoute.MindTree -> Routed {
            MindTreePickerScreen(config = config, onboardingStore = onboardingStore, onAdvance = ::advance)
          }

          OnboardingRoute.CreateAccount -> Routed { CreateAccountScreen(onAdvance = ::advance) }

          OnboardingRoute.SignUp -> Routed {
            SignUpScreen(
              accountStore = accountStore,
              onboardingStore = onboardingStore,
              onAdvance = ::advance,
              onSubmittingChange = { authInFlight = it },
            )
          }

          OnboardingRoute.LogIn -> Routed {
            LogInScreen(
              accountStore = accountStore,
              onboardingStore = onboardingStore,
              remote = remote,
              onAdvance = ::advance,
              onSubmittingChange = { authInFlight = it },
            )
          }

          OnboardingRoute.CraftingSpace -> CraftingSpaceScreen(onboardingStore = onboardingStore, remote = remote)
        }
      }
    }

    AnimatedVisibility(
      visible = OnboardingNavigator.showsChrome(nav) && !authInFlight,
      enter = fadeIn(hush()),
      exit = fadeOut(hush()),
      modifier = Modifier.align(Alignment.TopCenter),
    ) {
      val progress = onboardingProgress(nav.current, config.questions.size)
      OnboardingChromeBar(
        onBack = ::goBack,
        progress = progress?.fraction,
        fractionLabel = progress?.let {
          stringResource(R.string.onboarding_progress_fraction, it.step, it.total)
        },
      )
    }

    ripple?.let { context ->
      key(context) {
        RippleRevealOverlay(
          origin = context.origin,
          onFinished = { ripple = null },
          modifier = Modifier.fillMaxSize(),
        ) {
          WelcomeScreen(
            configState = WelcomeConfigState.Ready,
            onBegin = {},
            onLogIn = {},
            onRetry = {},
            video = WelcomeVideo.Still(context.still),
          )
        }
      }
    }
  }
}

/**
 * Pads a routed screen's top by the chrome's height, so content starts below
 * the floating back button and progress bar. Each screen bakes in its own
 * inset (iOS's `routed(_:)`), so differing insets never reflow mid-crossfade.
 * The screen still applies the system-bar insets itself; plain padding doesn't
 * consume them.
 */
@Composable
private fun Routed(content: @Composable () -> Unit) {
  Box(Modifier.fillMaxSize().padding(top = OnboardingChromeHeight)) {
    content()
  }
}

/**
 * Whether this config can carry a member through the flow: at least one
 * question, every question with at least one option, and at least one Mind
 * Tree. An empty or malformed config decodes fine but would render a blank
 * quiz or picker with no way forward, so the fetch treats it as failed and the
 * welcome screen offers Try again.
 */
private fun OnboardingConfig.isUsable(): Boolean =
  questions.isNotEmpty() && questions.all { it.options.isNotEmpty() } && mindTrees.isNotEmpty()

/** Where the fetch of the server-driven questions and trees has got to. */
private sealed interface ConfigLoad {
  data object Loading : ConfigLoad
  data class Loaded(val config: OnboardingConfig) : ConfigLoad
  data object Failed : ConfigLoad
}

/** One ripple send-off: the frozen welcome frame, and the window point it spreads from. */
private class RippleContext(val still: ImageBitmap?, val origin: Offset?)

/**
 * Remembers the last touch-down in window pixels, outside Compose state so
 * tracking a touch never recomposes anything. A null origin (the advance came
 * from an accessibility action, not a finger) lets [RippleRevealOverlay] fall
 * back to where the welcome CTAs sit.
 */
private class RippleTouchTracker {
  var coordinates: LayoutCoordinates? = null
  var location: Offset? = null

  fun origin(): Offset? = location
}

@Preview(showBackground = true, name = "Onboarding — full flow")
@Composable
private fun OnboardingCoordinatorPreview() {
  // The host backdrop AppRoot provides in the app, so the preview is true to
  // what ships. The welcome screen's live video does not render in a preview.
  DeepTheme {
    Box(Modifier.fillMaxSize().background(Color.moonCream)) {
      AtmosphereBackground(animated = false)
      OnboardingCoordinator(
        accountStore = MockAccountStore.signedOut,
        onboardingStore = MockOnboardingProgressStore.fresh,
        remote = MockOnboardingRemote(),
      )
    }
  }
}
