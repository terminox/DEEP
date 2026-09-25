package io.appbeyond.freelance.deep.feature.onboarding.components

import androidx.compose.runtime.Composable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier

/**
 * The drift a screen's *content block* wears while the coordinator crossfades
 * whole screens.
 *
 * Ported from Deep/Deep/Features/Onboarding/Transition/OnboardingContentDrift.swift
 * and `SoftDriftTransition.swift`. The hand-off happens in two layers: the
 * coordinator fades whole screens (pure opacity, so fixed elements — the chrome,
 * footer CTAs — hold perfectly still), while each screen's content additionally
 * drifts `Dp.drift` in the routing direction with no fade of its own, so the two
 * layers never compound opacities. The iOS `SoftDrift.veil` blur is dropped:
 * `Modifier.blur` is a no-op below API 31, and blurring anything over the
 * atmosphere turns its orbs into hard discs.
 *
 * The coordinator builds the modifier inside its `AnimatedContent` (it needs
 * that scope's `animateEnterExit`) and provides it here — the Compose twin of
 * iOS injecting `onboardingNavDirection` through the environment. The default is
 * identity, so a leaf screen previews without a coordinator.
 */
val LocalOnboardingContentDrift = staticCompositionLocalOf<Modifier> { Modifier }

/** Apply to a screen's content block — never its footer CTA — so it drifts into place. */
@Composable
fun Modifier.onboardingContentDrift(): Modifier = this.then(LocalOnboardingContentDrift.current)
