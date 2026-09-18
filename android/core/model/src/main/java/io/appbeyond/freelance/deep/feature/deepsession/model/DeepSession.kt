package io.appbeyond.freelance.deep.feature.deepsession.model

import kotlin.math.max
import kotlin.math.roundToInt
import kotlin.time.Duration
import kotlin.time.Duration.Companion.seconds

/**
 * A guided breathing practice — the pattern the orb and cue text follow, and how
 * many rounds make one session.
 *
 * Ported from Deep/Deep/Features/DeepSession/Models/DeepSession.swift.
 *
 * One deliberate divergence: [title] and [tagline] arrive as plain strings rather
 * than resolving themselves. iOS has to reach for `Bundle.app` inside a computed
 * `static var`, because a `static let` would resolve its copy once per process
 * and pin the app to whichever language it launched in. Here the type is in a
 * module with no Android dependency at all, so localisation stays where it
 * belongs — at the UI edge, reading from resources — and this type stays pure and
 * trivially testable.
 */
data class DeepSession(
  val id: String,
  /** Serif card and screen title, e.g. "Balancing breath". */
  val title: String,
  /** One gentle line under the title, in the app's second-person voice. */
  val tagline: String,
  /** Time spent breathing in. */
  val inhale: Duration = 4.seconds,
  /**
   * Time spent breathing out. Longer than the inhale — the physiological "sigh"
   * ratio that settles the nervous system. See DESIGN.md.
   */
  val exhale: Duration = 6.seconds,
  /** How many inhale-exhale rounds complete the session. */
  val cycles: Int,
) {
  /** One full inhale-exhale round. */
  val cycleDuration: Duration get() = inhale + exhale

  /** Whole-session length. */
  val duration: Duration get() = cycleDuration * cycles

  /**
   * Rounded-up whole minutes — the unit a session's length is chosen and credited
   * in. Exact for any session built by [lasting].
   */
  val durationMinutes: Int
    get() = max(1, kotlin.math.ceil(duration.inWholeMilliseconds / 60_000.0).toInt())

  /**
   * A copy of this practice stretched to [minutes], in however many rounds its own
   * pattern needs to fill that length.
   *
   * The id rides along: it is the same practice, only longer, and a fresh id on
   * every recomposition would churn whatever carries it into the run.
   */
  fun lasting(minutes: Int): DeepSession = copy(
    cycles = max(
      1,
      ((minutes * 60_000.0) / cycleDuration.inWholeMilliseconds).roundToInt(),
    ),
  )
}

/** The lengths a Deep Session can be set to, in whole minutes. */
object DeepSessionLength {
  val range = 1..10

  /**
   * What a first visit opens on — the one-minute practice the app shipped with.
   * Every visit after that opens on whatever was last chosen.
   */
  val opening = range.first
}
