package io.appbeyond.freelance.deep.feature.globalpause.model

import java.time.Duration
import java.time.Instant

/** The four phases of one occurrence, by their wire keys. */
enum class PausePhaseKey(val wireName: String) {
  Lobby("lobby"),
  Welcome("welcome"),
  Meditation("meditation"),
  Feedback("feedback");

  companion object {
    /** An unknown key from a newer server reads as null and is dropped. */
    fun fromWire(value: String): PausePhaseKey? = entries.firstOrNull { it.wireName == value }
  }
}

/**
 * One phase of the pause, as absolute instants. The server resolves all
 * wall-clock and timezone math; the client only ever compares instants.
 */
data class PausePhaseWindow(
  val key: PausePhaseKey,
  val startsAt: Instant,
  val endsAt: Instant,
)

/**
 * One Global Pause occurrence, fully resolved: phase instants, event audio,
 * the welcome copy, and the intention options for the feedback phase.
 *
 * A day can hold several sessions. The server always resolves exactly one of
 * them — the one under way, else the next — so this stays a single occurrence
 * with four phases, and [nextOccurrenceMeditationStart] says what follows it.
 *
 * Ported from Deep/Deep/Features/GlobalPause/Models/PauseSchedule.swift.
 *
 * @property lobbyDuration how long DJ Fuku's lounge set runs, measured
 *   server-side off [lobbyAudioUrl]. Zero on a server too old to send it, which
 *   reads as "no set tonight" rather than a broadcast of unknown length.
 * @property nextOccurrenceMeditationStart when the meditation begins in the
 *   occurrence *after* this one. Null on a server that only ever runs one pause
 *   a day — see [nextMeditationStart].
 */
data class PauseSchedule(
  val pauseDate: String,
  val timezone: String,
  val phases: List<PausePhaseWindow>,
  val lobbyAudioUrl: String?,
  val lobbyDuration: Duration,
  val meditationAudioUrl: String?,
  val meditationDuration: Duration,
  val nextOccurrenceMeditationStart: Instant? = null,
  val welcomeMessages: List<String> = emptyList(),
  val intentions: List<Intention> = emptyList(),
) {

  fun window(key: PausePhaseKey): PausePhaseWindow? = phases.firstOrNull { it.key == key }

  /**
   * The instant this whole occurrence is over. Null only for a phase-less
   * schedule, which is what a server with no sessions configured answers with.
   */
  val windowEnd: Instant? get() = phases.maxOfOrNull { it.endsAt }

  /**
   * The next phase boundary strictly after [date], or null once the whole
   * window has passed (time to re-fetch the next occurrence).
   */
  fun nextBoundary(after: Instant): Instant? =
    phases
      .flatMap { listOf(it.startsAt, it.endsAt) }
      .filter { it.isAfter(after) }
      .minOrNull()

  /**
   * When the meditation next begins, strictly after [after]: this occurrence's
   * start while it is still ahead, then the next occurrence the server named.
   *
   * The fallback is a 24h projection, and on the server that omits the field
   * it is exact rather than a guess: only a server running one pause a day
   * leaves [nextOccurrenceMeditationStart] null, and there the next occurrence
   * really is the same wall clock tomorrow.
   */
  fun nextMeditationStart(after: Instant): Instant? {
    val meditation = window(PausePhaseKey.Meditation) ?: return null
    if (after.isBefore(meditation.startsAt)) return meditation.startsAt
    // Guards a server echoing this occurrence's own start, which would leave
    // the countdown target permanently in the past.
    val next = nextOccurrenceMeditationStart
    if (next != null && next.isAfter(meditation.startsAt)) return next
    return meditation.startsAt.plus(Duration.ofHours(24))
  }
}

/** A join resolved to coordinates — what the globe's spark pipeline consumes. */
data class PauseJoinPoint(val lat: Float, val lon: Float)

/**
 * A moment-in-time reading of the live event: who's here and where.
 *
 * @property byContinent tallied by continent code ("AS", "EU", "NA"…) — the
 *   reading the live session names beneath the globe. Wider than [byCountry]:
 *   it also holds people whose device never named a country.
 * @property locations located participants as server-clustered lat/lon points.
 * @property unlocatedByCountry participants the server couldn't geolocate,
 *   tallied by country; the globe renders these at the country centroid.
 */
data class PauseLiveSnapshot(
  val serverNow: Instant,
  val participantCount: Int,
  val byCountry: Map<String, Int> = emptyMap(),
  val byContinent: Map<String, Int> = emptyMap(),
  val locations: List<GeoPoint> = emptyList(),
  val unlocatedByCountry: Map<String, Int> = emptyMap(),
  val recentJoins: List<Join> = emptyList(),
) {

  /** One arrival. [lat]/[lon] are null when the server couldn't place the IP. */
  data class Join(val iso: String, val at: Instant, val lat: Float?, val lon: Float?)

  /** One clustered participant location. */
  data class GeoPoint(val lat: Float, val lon: Float, val count: Int)
}
