package io.appbeyond.freelance.deep.feature.globalpause.store

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.time.Duration

/** What Fuku's Lounge is doing with sound right now. */
sealed interface LoungeRadioState {
  data object Off : LoungeRadioState

  /**
   * The set is on air. [isMuted] is the member's own choice, made by tapping
   * the ON AIR pill — the broadcast keeps running underneath either way, so
   * unmuting rejoins it live rather than resuming where it was silenced.
   */
  data class OnAir(val isMuted: Boolean) : LoungeRadioState
}

/**
 * The lounge's radio: one track, joined at an offset, mutable, stoppable.
 *
 * Deliberately smaller than DEEP Sound's `SoundPlaying` and shaped differently
 * from [GlobalPauseAudioPlaying]. There is no scrub and no skip — you cannot
 * move around inside a broadcast — but unlike the meditation, which offers no
 * transport at all, this one is happy to be silenced. It is background music
 * in a room, not a sit.
 *
 * Ported from Deep/Deep/Features/GlobalPause/Audio/LoungeRadioPlaying.swift.
 */
interface LoungeRadioPlaying {

  val state: StateFlow<LoungeRadioState>

  /**
   * Recovery seam: after an interruption, a stall or a return to the app the
   * player re-seeks to whatever offset this returns, so it lands back on the
   * live edge instead of resuming a broadcast everyone else has moved past.
   * Null from the provider means the set has signed off, and the radio stops;
   * no provider at all resumes in place.
   */
  var liveOffsetProvider: (() -> Duration?)?

  /**
   * Joins the set [offset] in. Calling it again with the same URL and a nearby
   * offset is a no-op ([LoungeRadio.isAlreadyTuned]), so a recomposition can't
   * restart the track.
   */
  fun join(url: String, offset: Duration)

  /** Silences or unsilences the set without leaving it. */
  fun setMuted(muted: Boolean)

  /**
   * Tears everything down. Idempotent — called as the lounge leaves, and as the
   * meditation takes the room.
   */
  fun stop()
}

object LoungeRadio {

  /**
   * How far the playhead may already be from a requested offset before the
   * request counts as a real realign rather than a recomposition asking for
   * what is already playing. Comfortably wider than one poll's drift.
   */
  val REALIGN_TOLERANCE: Duration = Duration.ofSeconds(3)

  /**
   * Whether a join for [url] at [offset] asks for what is already playing —
   * [playingUrl] at [position] — and so must not restart the track.
   */
  fun isAlreadyTuned(playingUrl: String?, position: Duration?, url: String, offset: Duration): Boolean {
    if (playingUrl != url || position == null) return false
    return position.minus(offset).abs() < REALIGN_TOLERANCE
  }
}

/** A silent stand-in for previews and tests: it records what it was asked. */
class MockLoungeRadioPlayer(state: LoungeRadioState = LoungeRadioState.Off) : LoungeRadioPlaying {

  private val _state = MutableStateFlow(state)
  override val state: StateFlow<LoungeRadioState> = _state.asStateFlow()

  override var liveOffsetProvider: (() -> Duration?)? = null

  /** Every join asked for, for assertions. */
  val joined = mutableListOf<Pair<String, Duration>>()
  var stopCount = 0
    private set

  override fun join(url: String, offset: Duration) {
    joined += url to offset
    val muted = (_state.value as? LoungeRadioState.OnAir)?.isMuted ?: false
    _state.value = LoungeRadioState.OnAir(isMuted = muted)
  }

  override fun setMuted(muted: Boolean) {
    if (_state.value is LoungeRadioState.OnAir) _state.value = LoungeRadioState.OnAir(isMuted = muted)
  }

  override fun stop() {
    stopCount += 1
    _state.value = LoungeRadioState.Off
  }

  companion object {
    /** The set playing, unmuted. */
    fun onAir(): MockLoungeRadioPlayer = MockLoungeRadioPlayer(LoungeRadioState.OnAir(isMuted = false))
  }
}
