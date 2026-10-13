package io.appbeyond.freelance.deep.feature.globalpause

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.AnimatedVisibilityScope
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.core.view.WindowCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.globalpause.components.GlobalPauseIcons
import io.appbeyond.freelance.deep.feature.globalpause.globe.GlobeMode
import io.appbeyond.freelance.deep.feature.globalpause.globe.GlobeScene
import io.appbeyond.freelance.deep.feature.globalpause.globe.LocalGlobeRendering
import io.appbeyond.freelance.deep.feature.globalpause.model.ContinentPresence
import io.appbeyond.freelance.deep.feature.globalpause.model.GlobalPauseRewardSnapshot
import io.appbeyond.freelance.deep.feature.globalpause.model.SyncedClock
import io.appbeyond.freelance.deep.feature.globalpause.store.FixturePauseEventRemote
import io.appbeyond.freelance.deep.feature.globalpause.store.GlobalPauseAudioPlaying
import io.appbeyond.freelance.deep.feature.globalpause.store.GlobalPauseSession
import io.appbeyond.freelance.deep.feature.globalpause.store.GlobalPauseVisit
import io.appbeyond.freelance.deep.feature.globalpause.store.MockGlobalPauseAudioPlayer
import io.appbeyond.freelance.deep.feature.profile.DeepConfirmDialog
import io.appbeyond.freelance.deep.feature.profile.DialogAction
import io.appbeyond.freelance.deep.feature.profile.HeaderIconButton
import io.appbeyond.freelance.deep.feature.rewards.model.RewardReceipt
import io.appbeyond.freelance.deep.feature.rewards.screens.RewardRitualScreen
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.localization.DeviceRegion
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.hush
import io.appbeyond.freelance.deep.theme.moonCream
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import java.time.Duration
import java.util.Locale

/**
 * The presented Global Pause — the coordinator for one visit's flow: the live
 * meditation over the night sky and the globe, the reflection it crossfades
 * into, and the reward ritual that closes the night. Presented by `AppRoot`
 * over the whole shell, as the DEEP Session is.
 *
 * The flow itself lives in [GlobalPauseVisit] (`:core:model`), so it carries
 * on with the screen stopped — the phone locked mid-sit still reaches the
 * reflection on time, and the claim still goes out. This composes its phases
 * and owns the one confirmation: leaving mid-meditation asks first, because
 * the session is a live, shared moment ("The world keeps breathing — you can
 * rejoin while it's live.").
 *
 * The Android half of iOS's `GlobalPauseSessionController`. Its globe arrival
 * (a minute's turn landing on the member) and the card lift are week 7's; the
 * seams are [LocalGlobeRendering] and [currentCardLift].
 *
 * @param visibility the presentation's scope, for the card lift's target.
 * @param snapshot / receipt the books for the ending (`PauseNightRewards`).
 * @param memberName heads the composer — "Friend" when there is none.
 * @param onFinish the visit is over: dismiss.
 */
@Composable
fun GlobalPauseSessionCoordinator(
  session: GlobalPauseSession,
  scene: GlobeScene,
  audio: GlobalPauseAudioPlaying,
  snapshot: suspend () -> GlobalPauseRewardSnapshot,
  receipt: suspend (GlobalPauseRewardSnapshot) -> RewardReceipt,
  witnessContinuity: suspend () -> Unit,
  memberName: String?,
  onFinish: () -> Unit,
  modifier: Modifier = Modifier,
  visibility: AnimatedVisibilityScope? = null,
) {
  val scope = rememberCoroutineScope()
  val visit = remember { GlobalPauseVisit(session, audio, scope, snapshot, receipt) }
  val phase by visit.phase.collectAsStateWithLifecycle()
  val isPreparing by visit.isPreparing.collectAsStateWithLifecycle()
  val pause by session.state.collectAsStateWithLifecycle()
  val elapsed by audio.meditationElapsed.collectAsStateWithLifecycle()
  val lift = currentCardLift
  val rendering = LocalGlobeRendering.current
  val finished by rememberUpdatedState(onFinish)

  var revealed by remember { mutableStateOf(false) }
  var confirmingLeave by remember { mutableStateOf(false) }

  LaunchedEffect(visit) { visit.begin() }
  LaunchedEffect(phase) { if (phase == GlobalPauseVisit.Phase.Finished) finished() }
  // A leave confirmation still up as the meditation ends would strand the
  // member over the reflection — retire it.
  LaunchedEffect(phase) { if (phase !is GlobalPauseVisit.Phase.Meditating) confirmingLeave = false }
  DisposableEffect(visit) {
    onDispose {
      // Dismissed some other way (the shell went away): no ghost audio, no
      // ghost presence, and the world's lights go out with the session.
      visit.leave()
      scene.clear()
    }
  }

  // The overlay arrives empty and cascades in once the presentation lands.
  LaunchedEffect(Unit) {
    delay(lift.landingMillis)
    revealed = true
  }

  // The world's lights wait for the landing, then follow the live poll; the
  // member's own light flares as the globe comes to rest on them.
  LaunchedEffect(session, scene) {
    delay(lift.landingMillis + LIGHTS_DELAY_MILLIS)
    session.state
      .map { Triple(it.participantLocations, it.unlocatedByCountry, it.participantsByCountry) to it.myLocation }
      .distinctUntilChanged()
      .collect { (room, home) ->
        scene.locations = room.first
        scene.unlocatedByCountry = room.second
        scene.participantsByCountry = if (room.first.isEmpty() && room.second.isEmpty()) room.third else emptyMap()
        scene.homeLocation = home
      }
  }
  LaunchedEffect(session, scene) {
    delay(lift.landingMillis + LIGHTS_DELAY_MILLIS)
    session.joins.collect { scene.enqueueJoins(it) }
  }
  LaunchedEffect(session, scene) {
    delay(lift.landingMillis + ARRIVAL_MILLIS)
    session.state.value.myLocation?.let(scene::enqueueOwnJoin)
  }

  LightStatusBarIcons(enabled = phase is GlobalPauseVisit.Phase.Meditating || phase == GlobalPauseVisit.Phase.Arriving)

  BackHandler(enabled = phase !is GlobalPauseVisit.Phase.Rewarding && phase != GlobalPauseVisit.Phase.Finished) {
    when (phase) {
      is GlobalPauseVisit.Phase.Meditating, GlobalPauseVisit.Phase.Arriving -> confirmingLeave = true
      // The claim is already out; the ingest reconciles behind the exit.
      else -> visit.finish()
    }
  }

  Box(modifier.fillMaxSize()) {
    // The backdrop: the night sky and the globe, whole and centred.
    val backdrop = Modifier.fillMaxSize()
    Box(if (visibility != null) with(lift) { backdrop.cardLiftTarget(visibility) } else backdrop) {
      rendering.NightSky(Modifier.fillMaxSize())
      BoxWithConstraints(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        val side: Dp = minOf(maxWidth, maxHeight) * GLOBE_WIDTH_SHARE
        rendering.Globe(
          scene,
          GlobeMode.Session,
          Modifier
            .size(side)
            .offset(y = -maxHeight * GLOBE_RAISE_SHARE),
        )
      }
    }

    val meditating = phase as? GlobalPauseVisit.Phase.Meditating
    if (meditating != null) {
      GlobalPauseMeditationOverlay(
        elapsed = elapsed,
        duration = meditating.duration,
        participantCount = pause.participantCount,
        continents = ContinentPresence.row(pause.participantsByContinent),
        revealed = revealed,
      )
    }

    AnimatedVisibility(
      visible = meditating != null || phase == GlobalPauseVisit.Phase.Arriving,
      enter = fadeIn(hush()),
      exit = fadeOut(tween(CHROME_FADE_MILLIS)),
      modifier = Modifier
        .align(Alignment.TopStart)
        .statusBarsPadding()
        .padding(start = Dp.edge, top = 8.dp),
    ) {
      HeaderIconButton(
        icon = GlobalPauseIcons.Close,
        contentDescription = stringResource(R.string.pause_session_close),
        onClick = { confirmingLeave = true },
      )
    }

    // The ending: one opaque atmosphere for the reflection and the ritual,
    // faded in slowly over the meditation — longer than `hush`, as iOS's 1.5s.
    AnimatedVisibility(
      visible = phase == GlobalPauseVisit.Phase.Reflecting || phase is GlobalPauseVisit.Phase.Rewarding,
      enter = fadeIn(tween(ENDING_FADE_MILLIS, easing = hush<Float>().easing)),
      exit = fadeOut(hush()),
    ) {
      Box(Modifier.fillMaxSize().background(Color.moonCream)) {
        AtmosphereBackground()
        AnimatedContent(
          targetState = phase,
          contentKey = { it is GlobalPauseVisit.Phase.Rewarding },
          transitionSpec = { fadeIn(hush()) togetherWith fadeOut(hush()) },
          label = "pause-ending",
        ) { current ->
          if (current is GlobalPauseVisit.Phase.Rewarding) {
            RewardRitualScreen(
              receipt = current.receipt,
              continuityHeadline = stringResource(
                if (current.receipt.returnedToday) {
                  R.string.reward_continuity_headline_returned
                } else {
                  R.string.reward_continuity_headline_continues
                },
              ),
              onWitnessContinuity = witnessContinuity,
              onFinish = { visit.finish() },
              paintsBackground = false,
            )
          } else {
            val locale = LocalConfiguration.current.locales[0]
            GlobalPauseReflectionScreen(
              intentions = localizedIntentions(pause.schedule?.intentions),
              name = memberName?.takeIf { it.isNotBlank() } ?: stringResource(R.string.pause_composer_friend),
              place = devicePlace(LocalContext.current, locale),
              isPreparing = isPreparing,
              post = { message, intention -> session.post(message, intention) },
              submit = { intention -> session.submit(intention = intention, mood = null) },
              onContinue = { scope.launch { visit.continueToRewards() } },
            )
          }
        }
      }
    }

    if (confirmingLeave) {
      DeepConfirmDialog(
        title = stringResource(R.string.pause_leave_title),
        message = stringResource(R.string.pause_leave_message),
        actions = listOf(
          DialogAction(stringResource(R.string.pause_leave_stay)) { confirmingLeave = false },
          DialogAction(stringResource(R.string.pause_leave_confirm), destructive = true) {
            confirmingLeave = false
            visit.leave()
          },
        ),
        onDismissRequest = { confirmingLeave = false },
      )
    }
  }
}

/**
 * The country the post itself carries — the device's region, read from the
 * same source the session sends ([DeviceRegion]) — named in the member's
 * language.
 */
private fun devicePlace(context: Context, locale: Locale): String {
  val region = DeviceRegion.isoCode(context) ?: return ""
  return Locale("", region).getDisplayCountry(locale).ifBlank { region }
}

/**
 * The night sky wants light status-bar icons; the cream ending wants them dark
 * again. Restored as the session leaves.
 */
@Composable
private fun LightStatusBarIcons(enabled: Boolean) {
  val view = LocalView.current
  if (view.isInEditMode) return
  DisposableEffect(enabled) {
    val window = view.context.findActivity()?.window
    val controller = window?.let { WindowCompat.getInsetsController(it, view) }
    val before = controller?.isAppearanceLightStatusBars
    controller?.isAppearanceLightStatusBars = !enabled
    onDispose { if (before != null) controller.isAppearanceLightStatusBars = before }
  }
}

private tailrec fun Context.findActivity(): Activity? = when (this) {
  is Activity -> this
  is ContextWrapper -> baseContext.findActivity()
  else -> null
}

private const val LIGHTS_DELAY_MILLIS = 2_500L
private const val ARRIVAL_MILLIS = 6_000L
private const val ENDING_FADE_MILLIS = 1_500
private const val CHROME_FADE_MILLIS = 220
private const val GLOBE_WIDTH_SHARE = 0.92f
private const val GLOBE_RAISE_SHARE = 0.04f

@Preview(name = "Session — meditation")
@Composable
private fun GlobalPauseSessionPreview() {
  val remote = remember {
    FixturePauseEventRemote(
      scheduleToServe = FixturePauseEventRemote.occurrence(meditationAt = java.time.Instant.now().minus(Duration.ofMinutes(4))),
    )
  }
  val scope = rememberCoroutineScope()
  val session = remember {
    GlobalPauseSession(
      clock = SyncedClock(),
      remote = remote,
      scope = scope,
      presenceId = { "preview" },
      countryIso = { "TH" },
    )
  }
  DeepTheme {
    GlobalPauseSessionCoordinator(
      session = session,
      scene = remember { GlobeScene() },
      audio = remember { MockGlobalPauseAudioPlayer.meditating() },
      snapshot = { GlobalPauseRewardSnapshot.sample },
      receipt = { RewardReceipt.pauseNight },
      witnessContinuity = {},
      memberName = "Miyu",
      onFinish = {},
    )
  }
}
