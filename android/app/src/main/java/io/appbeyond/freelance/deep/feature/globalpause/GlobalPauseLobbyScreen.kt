package io.appbeyond.freelance.deep.feature.globalpause

import android.view.TextureView
import androidx.annotation.OptIn
import androidx.annotation.RawRes
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.util.lerp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.deepsound.SoundIcons
import io.appbeyond.freelance.deep.feature.deepsound.player.MockSoundPlayer
import io.appbeyond.freelance.deep.feature.deepsound.player.SoundPlaying
import io.appbeyond.freelance.deep.feature.globalpause.components.GlobalPauseCard
import io.appbeyond.freelance.deep.feature.globalpause.components.OnAirPill
import io.appbeyond.freelance.deep.feature.globalpause.components.PeaceMessageCard
import io.appbeyond.freelance.deep.feature.globalpause.globe.GlobeScene
import io.appbeyond.freelance.deep.feature.globalpause.model.FukuClip
import io.appbeyond.freelance.deep.feature.globalpause.model.LoungeBroadcast
import io.appbeyond.freelance.deep.feature.globalpause.model.PeaceMessagesPage
import io.appbeyond.freelance.deep.feature.globalpause.model.SyncedClock
import io.appbeyond.freelance.deep.feature.globalpause.store.FixturePauseEventRemote
import io.appbeyond.freelance.deep.feature.globalpause.store.GlobalPauseSession
import io.appbeyond.freelance.deep.feature.globalpause.store.LoungeRadioPlaying
import io.appbeyond.freelance.deep.feature.globalpause.store.MockLoungeRadioPlayer
import io.appbeyond.freelance.deep.feature.globalpause.store.PeaceMessageFeed
import io.appbeyond.freelance.deep.feature.profile.HeaderIconButton
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.HeroRefreshable
import io.appbeyond.freelance.deep.shared.components.LocalMiniPlayerClearance
import io.appbeyond.freelance.deep.shared.components.LoopingVideoView
import io.appbeyond.freelance.deep.shared.components.StretchyHero
import io.appbeyond.freelance.deep.shared.components.rememberHeroPull
import io.appbeyond.freelance.deep.shared.components.ScrollToTopOnReselect
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.rhythm
import io.appbeyond.freelance.deep.theme.settle
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.launch
import java.time.Duration
import java.time.LocalTime

/**
 * Fuku's Lounge — the room the Home card opens into, pushed onto Home's stack
 * like any other leaf. DJ Fuku full-bleed in the stretchy hero, the Global
 * Pause card riding up over him, and below it the peace-message feed, paged
 * as the last card comes into view.
 *
 * The hero follows the member's own hour, so the room looks like the time of
 * day they are actually in. Once a session, at the top of the lobby phase,
 * Fuku goes on air: the intro clip plays aloud, hands off to that same
 * ambient footage, and the lounge track streams underneath until it runs out.
 * It is a broadcast, not a playlist — keyed to the synced clock, so walking in
 * late drops you into the middle of the set — and the ON AIR badge burns for
 * exactly the set's minutes. Tapping the badge mutes whichever is playing.
 *
 * Ported from Deep/Deep/Features/GlobalPause/Screens/GlobalPauseLobbyView.swift.
 *
 * @param fetchMessages one page of `GET /pause/messages`.
 * @param soundPlayer paused for the set, intro and music both; and if the
 *   member presses play on their own music, theirs wins and the set steps aside.
 * @param radio the lounge track. Owned outside the lounge, so the Global Pause
 *   can silence it on its way in; the lounge stops it as it leaves.
 * @param onJoin the live card was tapped: present the session.
 */
@Composable
fun GlobalPauseLobbyScreen(
  session: GlobalPauseSession,
  scene: GlobeScene,
  fetchMessages: suspend (limit: Int, cursor: String?) -> PeaceMessagesPage,
  soundPlayer: SoundPlaying,
  radio: LoungeRadioPlaying,
  onJoin: () -> Unit,
  onBack: () -> Unit,
  modifier: Modifier = Modifier,
) {
  val pause by session.state.collectAsStateWithLifecycle()
  val feed = remember { PeaceMessageFeed(fetch = fetchMessages) }
  val feedState by feed.state.collectAsStateWithLifecycle()
  val lift = currentCardLift

  var stage by remember { mutableStateOf<LoungeBroadcast.Stage>(LoungeBroadcast.Stage.Off) }
  var isMuted by remember { mutableStateOf(false) }
  var ambient by remember { mutableStateOf(FukuClip.ambient(LocalTime.now().hour)) }

  // Reads the clock once and puts the room where it belongs — at the set's
  // edges, as the intro finishes, and on arrival; never per frame.
  fun resolveStage(afterIntro: Boolean = false) {
    ambient = FukuClip.ambient(LocalTime.now().hour)
    val now = session.clock.now()
    val broadcast = session.loungeBroadcast
    val next = when {
      broadcast == null -> LoungeBroadcast.Stage.Off
      afterIntro -> broadcast.stageAfterIntro(now)
      else -> broadcast.stage(now)
    }
    // The intro is one clip playing through; re-entering it would replay it.
    if (next is LoungeBroadcast.Stage.Intro && stage is LoungeBroadcast.Stage.Intro) return
    stage = next

    when (next) {
      LoungeBroadcast.Stage.Off -> radio.stop()
      is LoungeBroadcast.Stage.Intro -> {
        // Fuku is talking over his own clip; the track waits its turn.
        radio.stop()
        soundPlayer.pause()
      }
      is LoungeBroadcast.Stage.Music -> {
        soundPlayer.pause()
        radio.liveOffsetProvider = { session.loungeElapsed }
        val url = session.state.value.schedule?.lobbyAudioUrl ?: return
        radio.join(url, next.offset)
        radio.setMuted(isMuted)
      }
    }
  }

  LaunchedEffect(Unit) {
    // Re-entering the lounge re-resolves the schedule against the synced
    // clock, so a server-side time jump lands without a relaunch.
    launch { session.start() }
    feed.loadInitial()
  }
  // The session flips this at the set's edges off its own boundary timer.
  LaunchedEffect(pause.isFukuOnAir, pause.schedule) { resolveStage() }
  // Their own music wins if they choose it: pressing play takes the room back
  // — set off, badge down — rather than two pieces of music at once. Only a
  // press made here counts, not whatever was already playing as they walked in
  // (the set pauses that).
  LaunchedEffect(soundPlayer) {
    soundPlayer.playback
      .map { it.isPlaying }
      .distinctUntilChanged()
      .drop(1)
      .filter { it }
      .collect {
        if (stage != LoungeBroadcast.Stage.Off) {
          radio.stop()
          stage = LoungeBroadcast.Stage.Off
        }
      }
  }
  // Leaving the room leaves the broadcast — back, or another tab. The session
  // keeps running it; coming back rejoins wherever it has got to.
  DisposableEffect(radio) { onDispose { radio.stop() } }

  val listState = rememberLazyListState()
  ScrollToTopOnReselect(listState)
  val (pull, nestedScroll) = rememberHeroPull(listState)
  val bottomInset = Dp.rhythm * 2 + LocalMiniPlayerClearance.current
  val shown = PeaceMessageFeed.displayed(feedState.messages, pause.postedMessage)
  val intentions = localizedIntentions(pause.schedule?.intentions)

  // Pages append as the last card comes into view.
  val lastId by rememberUpdatedState(shown.lastOrNull()?.id)
  LaunchedEffect(listState, feed) {
    snapshotFlow { listState.layoutInfo.visibleItemsInfo.lastOrNull()?.key }
      .distinctUntilChanged()
      .collect { key -> if (key != null && key == lastId) feed.loadMore() }
  }

  HeroRefreshable(
    pull = pull,
    onRefresh = {
      coroutineScope {
        launch { session.start() }
        feed.refresh()
      }
    },
    modifier = modifier,
  ) {
    Box(Modifier.fillMaxSize().background(Color.moonCream)) {
      AtmosphereBackground()

      LazyColumn(
        state = listState,
        modifier = Modifier.fillMaxSize().nestedScroll(nestedScroll),
        contentPadding = PaddingValues(bottom = bottomInset),
      ) {
        item(key = "hero") {
          StretchyHero(pull = pull, listState = listState) {
            val intro = stage as? LoungeBroadcast.Stage.Intro
            // A different composable per kind, so handing off from the intro
            // tears it down and builds the loop cleanly.
            key(intro != null, ambient) {
              if (intro != null) {
                FukuIntroVideo(
                  startAt = intro.elapsed,
                  isMuted = isMuted,
                  onEnded = { resolveStage(afterIntro = true) },
                  rejoinAt = {
                    // Back from the background: the broadcast moved on without
                    // us. Still in the intro, rejoin it where it is now;
                    // otherwise hand the room to whatever comes next.
                    val now = session.loungeBroadcast?.stage(session.clock.now())
                    if (now is LoungeBroadcast.Stage.Intro) {
                      now.elapsed
                    } else {
                      resolveStage()
                      null
                    }
                  },
                  modifier = Modifier.fillMaxSize(),
                )
              } else {
                LoopingVideoView(resource = ambient.rawResource, modifier = Modifier.fillMaxSize())
              }
            }
          }
        }

        item(key = "room") {
          Column(
            Modifier.offset(y = -HERO_OVERLAP),
            verticalArrangement = Arrangement.spacedBy(Dp.rhythm),
          ) {
            if (stage != LoungeBroadcast.Stage.Off) {
              OnAirPill(
                isMuted = isMuted,
                onTap = {
                  isMuted = !isMuted
                  radio.setMuted(isMuted)
                },
                modifier = Modifier.padding(horizontal = Dp.edge),
              )
            }
            GlobalPauseCard(
              state = pause.cardState,
              scene = scene,
              now = session.clock::now,
              onJoin = onJoin,
              modifier = with(lift) { Modifier.padding(horizontal = Dp.edge).cardLiftSource() },
            )
            if (shown.isNotEmpty()) {
              Text(
                stringResource(R.string.pause_messages_title),
                style = DeepType.sectionTitle,
                color = Color.deepPlum,
                modifier = Modifier
                  .padding(horizontal = Dp.edge)
                  .semantics { heading() },
              )
            }
          }
        }

        items(shown, key = { it.id }) { message ->
          PeaceMessageCard(
            message = message,
            intentions = intentions,
            modifier = Modifier
              .offset(y = -HERO_OVERLAP)
              .padding(horizontal = Dp.edge, vertical = 6.dp),
          )
        }

        if (feedState.isLoadingMore) {
          item(key = "loading-more") {
            Box(Modifier.fillMaxWidth().offset(y = -HERO_OVERLAP).padding(8.dp), contentAlignment = Alignment.Center) {
              CircularProgressIndicator(color = Color.driftGrey, strokeWidth = 2.dp, modifier = Modifier.size(20.dp))
            }
          }
        }
      }

      // The feed reaches the title once the hero's foot (less the overlap the
      // first message rides up into) passes under the bar.
      val density = LocalDensity.current
      var barHeight by remember { mutableIntStateOf(0) }
      val scrolledUnder by remember {
        derivedStateOf {
          val hero = listState.layoutInfo.visibleItemsInfo.firstOrNull { it.key == "hero" }
          val reach = barHeight + with(density) { HERO_OVERLAP.roundToPx() }
          hero == null || hero.offset + hero.size < reach
        }
      }
      LoungeTopBar(
        onBack = onBack,
        scrolledUnder = scrolledUnder,
        modifier = Modifier
          .align(Alignment.TopCenter)
          .onSizeChanged { barHeight = it.height },
      )
    }
  }
}

/**
 * The back chevron and the room's name, over a cream veil — Android's answer
 * to iOS's progressive blur under the inline title: there is no backdrop blur
 * below API 31, and the hero's art is bright.
 *
 * Over the hero the veil is a light wash. Once the feed is [scrolledUnder]
 * the title it firms into a near-opaque seat that holds through the title's
 * line and fades only in a tail below it — at the old wash's density the
 * messages' text read straight through the title (QA round 1, B10).
 */
@Composable
private fun LoungeTopBar(onBack: () -> Unit, scrolledUnder: Boolean, modifier: Modifier = Modifier) {
  val firmness by animateFloatAsState(
    targetValue = if (scrolledUnder) 1f else 0f,
    animationSpec = settle(),
    label = "lounge-veil",
  )
  Box(
    modifier
      .fillMaxWidth()
      .drawBehind {
        val tailStart = (1f - VEIL_TAIL.toPx() / size.height).coerceIn(0f, 1f)
        val top = lerp(VEIL_REST_TOP_ALPHA, VEIL_FIRM_TOP_ALPHA, firmness)
        val seat = lerp(VEIL_REST_SEAT_ALPHA, VEIL_FIRM_SEAT_ALPHA, firmness)
        drawRect(
          Brush.verticalGradient(
            0f to Color.moonCream.copy(alpha = top),
            tailStart to Color.moonCream.copy(alpha = seat),
            1f to Color.Transparent,
          ),
        )
      }
      .statusBarsPadding()
      .padding(horizontal = Dp.edge)
      .padding(top = 8.dp, bottom = 8.dp + VEIL_TAIL),
    contentAlignment = Alignment.Center,
  ) {
    HeaderIconButton(
      icon = SoundIcons.ChevronBack,
      contentDescription = stringResource(R.string.deepsound_back),
      onClick = onBack,
      modifier = Modifier.align(Alignment.CenterStart),
    )
    Text(
      text = stringResource(R.string.pause_lounge_title),
      style = DeepType.sectionTitle,
      color = Color.deepPlum,
      maxLines = 1,
      overflow = TextOverflow.Ellipsis,
      textAlign = TextAlign.Center,
      modifier = Modifier
        .padding(horizontal = 56.dp)
        .semantics { heading() },
    )
  }
}

/**
 * Fuku's intro, once, with its own voice, joined [startAt] in. Reports its end
 * so the room hands off to the ambient loop; [isMuted] silences it in place.
 *
 * Silent while DEEP is in the background, as [LoopingVideoView] is — Fuku
 * talking from a pocket is nobody's broadcast. Coming back, it asks
 * [rejoinAt] where the broadcast is now and seeks there, the way a radio
 * would; null means the intro is over and the room is handing off.
 */
@OptIn(UnstableApi::class)
@Composable
private fun FukuIntroVideo(
  startAt: Duration,
  isMuted: Boolean,
  onEnded: () -> Unit,
  rejoinAt: () -> Duration?,
  modifier: Modifier = Modifier,
) {
  val context = LocalContext.current
  val ended by rememberUpdatedState(onEnded)
  val currentRejoinAt by rememberUpdatedState(rejoinAt)
  val player = remember {
    ExoPlayer.Builder(context)
      // Media, with focus: Fuku talking quiets whatever else is playing.
      .setAudioAttributes(
        AudioAttributes.Builder().setUsage(C.USAGE_MEDIA).setContentType(C.AUDIO_CONTENT_TYPE_MOVIE).build(),
        /* handleAudioFocus = */ true,
      )
      .build()
      .apply {
        setMediaItem(MediaItem.fromUri("android.resource://${context.packageName}/${R.raw.fuku_intro}"))
        repeatMode = Player.REPEAT_MODE_OFF
        prepare()
        seekTo(startAt.toMillis())
        playWhenReady = true
      }
  }
  LaunchedEffect(isMuted) { player.volume = if (isMuted) 0f else 1f }
  DisposableEffect(player) {
    val listener = object : Player.Listener {
      override fun onPlaybackStateChanged(state: Int) {
        if (state == Player.STATE_ENDED) ended()
      }
    }
    player.addListener(listener)
    onDispose {
      player.removeListener(listener)
      player.release()
    }
  }
  val lifecycleOwner = LocalLifecycleOwner.current
  DisposableEffect(lifecycleOwner, player) {
    // Registering replays the current ON_START; only a real return rejoins.
    var stopped = false
    val observer = LifecycleEventObserver { _, event ->
      when (event) {
        Lifecycle.Event.ON_STOP -> {
          stopped = true
          player.pause()
        }
        Lifecycle.Event.ON_START -> if (stopped) {
          stopped = false
          currentRejoinAt()?.let { offset ->
            player.seekTo(offset.toMillis())
            player.play()
          }
        }
        else -> Unit
      }
    }
    lifecycleOwner.lifecycle.addObserver(observer)
    onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
  }
  AndroidView(modifier = modifier, factory = { TextureView(it).also(player::setVideoTextureView) })
}

/** The bundled loop for a clip. */
private val FukuClip.rawResource: Int
  @RawRes get() = when (this) {
    FukuClip.Morning -> R.raw.fuku_morning
    FukuClip.Afternoon -> R.raw.fuku_afternoon
    FukuClip.Night -> R.raw.fuku_night
    FukuClip.Midnight -> R.raw.fuku_midnight
    FukuClip.Intro -> R.raw.fuku_intro
  }

private val HERO_OVERLAP = 80.dp

/** The fade below the lounge title, so the veil never ends in an edge. */
private val VEIL_TAIL = 20.dp

// The lounge veil's cream, at the top edge and at the title's foot: a wash
// over the hero at rest, a seat for the title with the feed beneath it.
private const val VEIL_REST_TOP_ALPHA = 0.75f
private const val VEIL_REST_SEAT_ALPHA = 0.12f
private const val VEIL_FIRM_TOP_ALPHA = 0.96f
private const val VEIL_FIRM_SEAT_ALPHA = 0.9f

@Preview(showBackground = true, name = "Fuku's Lounge")
@Composable
private fun GlobalPauseLobbyPreview() {
  val remote = remember { FixturePauseEventRemote() }
  val scope = remember { CoroutineScope(kotlinx.coroutines.Dispatchers.Unconfined) }
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
    GlobalPauseLobbyScreen(
      session = session,
      scene = remember { GlobeScene() },
      fetchMessages = remote::messages,
      soundPlayer = remember { MockSoundPlayer.idle() },
      radio = remember { MockLoungeRadioPlayer() },
      onJoin = {},
      onBack = {},
    )
  }
}
