package io.appbeyond.freelance.deep.theme

import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.Easing
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.SpringSpec
import androidx.compose.animation.core.TweenSpec
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

// MARK: - Curves (single source of truth)

/**
 * Motion in Deep is always slower than expected. Defaults run 600–900ms against a
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
 * The breath itself — the exhale curve stretched over a whole breath phase, the
 * one motion in the app allowed to take entire seconds. Drives the Deep Session
 * orb: 4s in, 6s out.
 */
fun <T> breath(seconds: Float): TweenSpec<T> =
  tween(durationMillis = (seconds * 1000).toInt(), easing = DeepCurve.ExhaleEasing)

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

@Suppress("unused")
private val springSentinel = Spring.StiffnessMedium
