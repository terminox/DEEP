package io.appbeyond.freelance.deep.theme

import android.view.ViewPropertyAnimator
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.Easing
import androidx.compose.animation.core.InfiniteRepeatableSpec
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.SpringSpec
import androidx.compose.animation.core.TweenSpec
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.sin
import kotlin.math.sqrt

// MARK: - Curves (single source of truth)

/**
 * Motion in DEEP is always slower than expected. Defaults run 600–900ms against a
 * typical 200–300, and the easing approximates an exhale — slow start, slow end,
 * no overshoot. See DESIGN.md.
 *
 * Each curve is declared once here as raw control points plus a duration; the
 * functions below are thin projections. Ported from
 * Deep/Deep/Theme/DeepTheme.swift.
 */
private object DeepCurve {
  /** The hush between two moments — the long screen dissolve. */
  val HushEasing = CubicBezierEasing(0.3f, 0.0f, 0.2f, 1.0f)
  const val HushMillis = 1050

  /** The soft settling breath. The app's default. */
  val ExhaleEasing = CubicBezierEasing(0.32f, 0.0f, 0.36f, 1.0f)
  const val ExhaleMillis = 800

  /** New content arriving: scale 0.92 to 1.0 with opacity 0 to 1. Never a slide. */
  val BloomEasing = CubicBezierEasing(0.22f, 0.61f, 0.36f, 1.0f)
  const val BloomMillis = 700

  /** A wave set loose and left to calm — quick launch, long deceleration. */
  val RippleEasing = CubicBezierEasing(0.25f, 0.45f, 0.35f, 1.0f)
  const val RippleMillis = 1350

  /** A photograph breathing on its own — SwiftUI's `easeInOut`, over 18s each way. */
  val DriftEasing = CubicBezierEasing(0.42f, 0.0f, 0.58f, 1.0f)
  const val DriftMillis = 18_000

  /*
   * SwiftUI's spring(response:dampingFraction:) is parameterised differently from
   * Compose's spring(dampingRatio:stiffness:). dampingFraction maps straight onto
   * dampingRatio; response converts as stiffness = (2 * PI / response)^2 for unit
   * mass. The iOS token is response 0.55, dampingFraction 0.78, so:
   *
   *   stiffness = (2 * PI / 0.55)^2 = 130.5
   *
   * Both platforms therefore press into foam at the same rate.
   */
  const val SettleDampingRatio = 0.78f
  const val SettleStiffness = 130.5f

  /*
   * The card lift, iOS `GlobalPauseCardLiftTransition`: a calm rise
   * (response 0.60, dampingFraction 0.90 — it should glide, not spring) and a
   * critically damped return (0.45, 1.0) that eases exactly onto the card.
   * Played as a tween along the spring's own step response, so the rise can
   * wait out the chrome's pre-fade with a start delay a spring has no slot for.
   * Each runs until the response is within 0.2% of rest.
   */
  val LiftEasing = SpringEasing(response = 0.60f, dampingFraction = 0.90f, seconds = 0.70f)
  const val LiftMillis = 700
  val LandEasing = SpringEasing(response = 0.45f, dampingFraction = 1.0f, seconds = 0.60f)
  const val LandMillis = 600
}

/**
 * A spring's step response from rest, as an easing: `x(t)` for a unit-mass
 * spring of SwiftUI-style [response] and [dampingFraction], sampled over
 * [seconds] and normalised to land exactly on 1.
 */
private class SpringEasing(response: Float, dampingFraction: Float, private val seconds: Float) : Easing {
  private val omega = 2.0 * PI / response
  private val zeta = dampingFraction.toDouble()
  private val end = raw(seconds.toDouble())

  private fun raw(t: Double): Double = if (zeta >= 1.0) {
    1.0 - (1.0 + omega * t) * exp(-omega * t)
  } else {
    val damped = omega * sqrt(1.0 - zeta * zeta)
    1.0 - exp(-zeta * omega * t) * (cos(damped * t) + zeta / sqrt(1.0 - zeta * zeta) * sin(damped * t))
  }

  override fun transform(fraction: Float): Float = (raw(fraction * seconds.toDouble()) / end).toFloat()
}

// MARK: - Motion

/*
 * Top-level functions rather than an object, so a call site reads as though the
 * curve were built into Compose: `animateFloatAsState(v, animationSpec = exhale())`.
 * They are generic because every Compose animation spec is.
 *
 * Each returns its **concrete** spec type rather than the `AnimationSpec<T>`
 * interface, and that is load-bearing. `fadeIn`, `fadeOut` and
 * `slideInVertically` require a `FiniteAnimationSpec<T>`, and
 * `infiniteRepeatable` requires a `DurationBasedAnimationSpec<T>` — neither of
 * which an `AnimationSpec<T>` satisfies. Returning `TweenSpec<T>` satisfies both,
 * so a token can be handed to any of them.
 */

/**
 * The hush between two moments — the long screen dissolve. Reserved for
 * screen-level hand-offs; micro-feedback keeps [exhale] or [bloom].
 */
fun <T> hush(): TweenSpec<T> =
  tween(durationMillis = DeepCurve.HushMillis, easing = DeepCurve.HushEasing)

/** The app's default motion. */
fun <T> exhale(): TweenSpec<T> =
  tween(durationMillis = DeepCurve.ExhaleMillis, easing = DeepCurve.ExhaleEasing)

/** Content arriving. */
fun <T> bloom(): TweenSpec<T> =
  tween(durationMillis = DeepCurve.BloomMillis, easing = DeepCurve.BloomEasing)

/** Drives the welcome screen's ripple-reveal. */
fun <T> ripple(): TweenSpec<T> =
  tween(durationMillis = DeepCurve.RippleMillis, easing = DeepCurve.RippleEasing)

/**
 * Tapped elements depress softly and release with damped overshoot.
 *
 * A spring, so it is finite but not duration-based — it cannot drive
 * `infiniteRepeatable`, which is correct: a press is a response, not a loop.
 */
fun <T> settle(): SpringSpec<T> =
  spring(
    dampingRatio = DeepCurve.SettleDampingRatio,
    stiffness = DeepCurve.SettleStiffness,
    visibilityThreshold = null,
  )

/**
 * A photograph breathing on its own — Now Playing's full-screen artwork
 * drifting in and out while a sound plays. Slow enough to feel like air, not
 * motion; runs there and back until replaced, which is how it stops (hand the
 * value a finite [settle]). Never under reduced motion.
 */
fun <T> drift(): InfiniteRepeatableSpec<T> =
  infiniteRepeatable(
    animation = tween(durationMillis = DeepCurve.DriftMillis, easing = DeepCurve.DriftEasing),
    repeatMode = RepeatMode.Reverse,
  )

/**
 * The breath itself — the exhale curve stretched over a whole breath phase, the
 * one motion in the app allowed to take entire seconds. Drives the DEEP Session
 * orb: 4s in, 6s out.
 */
fun <T> breath(seconds: Float): TweenSpec<T> =
  tween(durationMillis = (seconds * 1000).toInt(), easing = DeepCurve.ExhaleEasing)

/**
 * The Global Pause card rising into the session — a glide along a calm
 * spring. [delayMillis] holds it while the card's chrome pre-fades.
 */
fun <T> lift(delayMillis: Int = 0): TweenSpec<T> =
  tween(durationMillis = DeepCurve.LiftMillis, delayMillis = delayMillis, easing = DeepCurve.LiftEasing)

/** The session's backdrop flying home onto the card — critically damped. */
fun <T> land(): TweenSpec<T> =
  tween(durationMillis = DeepCurve.LandMillis, easing = DeepCurve.LandEasing)

/**
 * The exhale as a platform View animation, for the one surface Compose doesn't
 * draw: the splash screen leaving. Same curve, same duration.
 */
fun ViewPropertyAnimator.exhale(): ViewPropertyAnimator =
  setDuration(DeepCurve.ExhaleMillis.toLong())
    .setInterpolator { DeepCurve.ExhaleEasing.transform(it) }

/** The breath's easing alone, for sampling where the animation runs. */
val breathEasing: Easing get() = DeepCurve.ExhaleEasing

/** The exhale's easing alone. */
val exhaleEasing: Easing get() = DeepCurve.ExhaleEasing

// MARK: - Held time

/**
 * The shortest a full-screen breathing beat may stay on screen. Whole-app waits
 * await this floor before dismissing the loading view, so a fast load never
 * flashes it.
 */
const val BREATHE_FLOOR_MILLIS = 900L

/**
 * How long a confirmed choice stays on screen as "done" before its sheet leaves
 * — long enough to be read as an acknowledgement, short enough not to stall.
 * The plant picker holds its "Growing …" bar this long (iOS's 0.5s).
 */
const val CONFIRMATION_HOLD_MILLIS = 500L

/**
 * How long a passing note stays before it settles back — Settings' "Restored"
 * beside its row, or the quiet line under it when the store couldn't be
 * reached (iOS's 2.5s on Restore purchases).
 */
const val NOTE_HOLD_MILLIS = 2_500L

/**
 * How long a card blooms in before the numbers on it start to move, so the
 * eye has landed before anything counts. Each reward ritual step waits this
 * long after its entrance (iOS's `Task.sleep(for: .milliseconds(350))`).
 */
const val ENTRANCE_HOLD_MILLIS = 350L

// MARK: - Travel

/**
 * How far content drifts as a screen hands off — the soft drift's one
 * magnitude. Going forward new content rises this far into place from below
 * while the old drifts up by the same; going back mirrors it. Never under
 * reduced motion.
 *
 * Ported from `SoftDrift.drop` in Deep/Deep/Shared/Transition/SoftDriftTransition.swift
 * (16pt). A Dp extension, like the spacing tokens, so it reads
 * `slideInVertically { Dp.drift.roundToPx() }`.
 */
val Dp.Companion.drift: Dp get() = 16.dp

/**
 * The breath of blur at the fully-veiled ends of the soft drift — the content
 * resolving into focus as it settles. Ported from `SoftDrift.veil` (6pt).
 * Only drawn where a real blur exists (API 31+), and never under reduced
 * motion.
 */
val Dp.Companion.veil: Dp get() = 6.dp

@Suppress("unused")
private val springSentinel = Spring.StiffnessMedium
