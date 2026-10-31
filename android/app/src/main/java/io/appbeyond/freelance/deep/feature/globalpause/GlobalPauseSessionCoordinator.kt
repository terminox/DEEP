package io.appbeyond.freelance.deep.feature.globalpause

import android.content.Context
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
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
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
import io.appbeyond.freelance.deep.shared.components.LightStatusBarIcons
import io.appbeyond.freelance.deep.shared.localization.DeviceRegion
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.hush
import io.appbeyond.freelance.deep.theme.moonCream
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull
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
 * The Android half of iOS's `GlobalPauseSessionController`. The globe — its
 * arrival turn onto the member, its lights, sparks and touch — is the
 * renderer's ([LocalGlobeRendering]); the card lift that brings the backdrop
 * in, and flies it home, is [currentCardLift]'s.
 *
 * @param visibility the presentation's scope, for the card lift's target.
 * @param snapshot / receipt / hydrate the books for the ending
 *   (`PauseNightRewards`); [hydrate] lets the journal take its first pull
 *   while the claim settles.
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
  hydrate: suspend () -> Unit = {},
) {
  val scope = rememberCoroutineScope()
  val visit = remember { GlobalPauseVisit(session, audio, scope, snapshot, receipt, hydrate) }
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

  // The overlay arrives empty and cascades in once the presentation lands —
  // and the night is up behind it: on a slow GPU the backdrop waits for the
  // globe's first frame, and the close button and LIVE pill stood over the
  // pale lounge until it came. iOS's backdrop is the card itself, so its
  // landing (`viewDidAppear`) is always onto the night.
  LaunchedEffect(Unit) {
    delay(lift.landingMillis)
    // Capped: a surface that never presents must not also withhold the way out.
    withTimeoutOrNull(READY_GRACE_MILLIS) { snapshotFlow { lift.isTargetReady }.first { it } }
    revealed = true
  }

  // The world's lights wait for the landing, then follow the live poll; the
  // member's own light flares as the globe comes to rest on them.
  LaunchedEffect(session, scene) {
    snapshotFlow { revealed }.first { it }
    delay(LIGHTS_DELAY_MILLIS)
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
    snapshotFlow { revealed }.first { it }
    delay(LIGHTS_DELAY_MILLIS)
    session.joins.collect { scene.enqueueJoins(it) }
  }
  // The member's own light flares as the arrival turn lands on them (iOS
  // `armArrivalTurn`): re-read at the turn's deadline, so the IP-resolved
  // point that replaced the country centroid is the one that flares — or, if
  // no location has come in by then, the moment the first one does.
  LaunchedEffect(session, scene) {
    snapshotFlow { revealed }.first { it }
    delay(ARRIVAL_TURN_MILLIS)
    val home = session.state.map { it.myLocation }.filterNotNull().first()
    if (visit.phase.value is GlobalPauseVisit.Phase.Meditating) scene.enqueueOwnJoin(home)
  }

  // Light icons over the night — flipped as the lift lands, not while the
  // card is still rising over the cream lounge (iOS `viewDidAppear`).
  LightStatusBarIcons(
    enabled = revealed && (phase is GlobalPauseVisit.Phase.Meditating || phase == GlobalPauseVisit.Phase.Arriving),
  )

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

    // The close button surfaces with the overlay, once the lift has landed —
    // never over the lounge's own back chevron while the card is rising.
    AnimatedVisibility(
      visible = revealed && (meditating != null || phase == GlobalPauseVisit.Phase.Arriving),
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
    // Finishing from it, the cream stays up on its last screen while the whole
    // presentation fades: fading it as well would uncover the night sky and
    // the session's last globe frame beneath, ghosting them over the lounge
    // (QA round 1, B6) — and would swap the ritual back to the reflection.
    val ending = phase.takeIf { it == GlobalPauseVisit.Phase.Reflecting || it is GlobalPauseVisit.Phase.Rewarding }
    val heldEnding = remember { mutableStateOf<GlobalPauseVisit.Phase?>(null) }
    SideEffect { if (ending != null) heldEnding.value = ending }
    val shownEnding = ending ?: heldEnding.value.takeIf { phase == GlobalPauseVisit.Phase.Finished }
    AnimatedVisibility(
      visible = shownEnding != null,
      enter = fadeIn(tween(ENDING_FADE_MILLIS, easing = hush<Float>().easing)),
      exit = fadeOut(hush()),
    ) {
      // While the cream covers the backdrop, leaving is a fade, not a flight.
      Box(with(lift) { Modifier.cardLiftCover() }.fillMaxSize().background(Color.moonCream)) {
        AtmosphereBackground()
        AnimatedContent(
          targetState = shownEnding ?: GlobalPauseVisit.Phase.Reflecting,
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

private const val LIGHTS_DELAY_MILLIS = 2_500L

/** Longest the overlay waits past the landing for the backdrop to be up —
 * the lift's own first-frame wait (4s) plus its flight, and a little over. */
private const val READY_GRACE_MILLIS = 6_000L
/** iOS's `arrivalTurn`, and the Earth's (`EarthEngine`): the world turns for a
 * minute after the landing and comes to rest on the member. */
private const val ARRIVAL_TURN_MILLIS = 60_000L
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
