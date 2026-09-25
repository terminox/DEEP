package io.appbeyond.freelance.deep.onboarding.model

/** Ported from `AppRootView.Phase`. */
enum class RootPhase { Restoring, Flow, Main }

/** !restored → Restoring; signedIn && completed → Main; else Flow. */
fun rootPhase(restored: Boolean, signedIn: Boolean, completedOnboarding: Boolean): RootPhase = when {
  !restored -> RootPhase.Restoring
  signedIn && completedOnboarding -> RootPhase.Main
  else -> RootPhase.Flow
}
