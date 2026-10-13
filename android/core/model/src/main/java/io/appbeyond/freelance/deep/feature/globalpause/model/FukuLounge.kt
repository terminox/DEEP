package io.appbeyond.freelance.deep.feature.globalpause.model

import java.time.Duration
import java.time.Instant

/**
 * The footage that plays in Fuku's Lounge. Four ambient loops follow the
 * member's own hour; the intro is the one that opens the nightly broadcast,
 * and the only one that carries sound.
 *
 * Ported from Deep/Deep/Features/GlobalPause/Models/FukuLounge.swift.
 */
enum class FukuClip {
  Morning,
  Afternoon,
  Night,
  Midnight,
  Intro;

  /** The bundled resource name — `fuku_morning` and so on, as on iOS. */
  val resource: String get() = "fuku_${name.lowercase()}"

  companion object {
    /**
     * The ambient clip for an hour of the *device's* day — the lounge shows a
     * member their own time of day, not Bangkok's.
     *
     * The first two bands are `GardenGreeting`'s salutation hours (5..<12,
     * 12..<17) so the two never disagree about what part of the day it is;
     * the evening is split into night and a genuinely late midnight.
     */
    fun ambient(hour: Int): FukuClip = when (hour) {
      in 5..11 -> Morning
      in 12..16 -> Afternoon
      in 17..23 -> Night
      else -> Midnight
    }
  }
}

/**
 * DJ Fuku's set for one occurrence, as instants: it opens at the top of its
 * lobby phase with the intro clip playing aloud, hands off to the lounge
 * track, and signs off when the track runs out.
 *
 * It is a broadcast, not a playlist — every stage is derived from one clock,
 * so two people who walk into the lounge a minute apart are in the same bar,
 * and a latecomer joins mid-track rather than starting it over.
 *
 * @property hardStop where the set is cut off whatever it has left to play:
 *   the welcome phase, which belongs to the pause itself. A longer track
 *   uploaded into an untouched window can shorten Fuku's set, but never talk
 *   over the countdown.
 */
data class LoungeBroadcast(
  val startsAt: Instant,
  val introDuration: Duration,
  val trackDuration: Duration,
  val hardStop: Instant,
) {

  sealed interface Stage {
    data object Off : Stage

    /** The intro clip, [elapsed] in, playing with its own sound. */
    data class Intro(val elapsed: Duration) : Stage

    /** The lounge track, [offset] in, under the ambient hero clip. */
    data class Music(val offset: Duration) : Stage
  }

  val endsAt: Instant
    get() = minOf(startsAt.plus(introDuration).plus(trackDuration), hardStop)

  fun stage(at: Instant): Stage {
    if (at.isBefore(startsAt) || !at.isBefore(endsAt)) return Stage.Off
    val elapsed = Duration.between(startsAt, at)
    return if (elapsed < introDuration) Stage.Intro(elapsed) else Stage.Music(elapsed.minus(introDuration))
  }

  /**
   * The stage at [at] given that the intro clip has just reported its own end.
   * The player and the clock disagree by a few milliseconds about when that
   * is, and on the wrong side of the difference [stage] would answer "still
   * the intro" for a clip that has stopped playing and will never report an
   * end again — leaving the set becalmed on a frozen last frame.
   */
  fun stageAfterIntro(at: Instant): Stage {
    if (!at.isBefore(endsAt)) return Stage.Off
    val elapsed = maxOf(Duration.between(startsAt, at), introDuration)
    return Stage.Music(elapsed.minus(introDuration))
  }

  fun isOnAir(at: Instant): Boolean = stage(at) != Stage.Off
}

/**
 * Tonight's set, or null when there is nothing to broadcast — no lobby phase,
 * no track, or a server too old to send the track's length.
 */
fun PauseSchedule.loungeBroadcast(introDuration: Duration): LoungeBroadcast? {
  val lobby = window(PausePhaseKey.Lobby) ?: return null
  if (lobbyAudioUrl == null || lobbyDuration <= Duration.ZERO) return null
  return LoungeBroadcast(
    startsAt = lobby.startsAt,
    introDuration = introDuration,
    trackDuration = lobbyDuration,
    hardStop = lobby.endsAt,
  )
}
