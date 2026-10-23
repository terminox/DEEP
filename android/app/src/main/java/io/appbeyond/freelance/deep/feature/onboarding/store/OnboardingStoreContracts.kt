package io.appbeyond.freelance.deep.feature.onboarding.store

import io.appbeyond.freelance.deep.auth.Account
import io.appbeyond.freelance.deep.onboarding.model.OnboardingConfig
import io.appbeyond.freelance.deep.onboarding.model.OnboardingState
import kotlinx.coroutines.flow.StateFlow

/*
 * The seams onboarding and accounts are built on. Each has a real conformer over
 * deep-api and a mock for previews, in their own files.
 *
 * Errors: every suspend member throws `DeepApiException` (networking/ApiError.kt)
 * and nothing else — its `message` is the display string.
 */

/** [AccountStore.swift] Conformers: `ApiAccountStore`, `MockAccountStore`. */
interface AccountStore {
  /**
   * Null when signed out. Hot; starts null until [restore] runs. The one
   * authority on "signed in": it also goes null when the server ends the
   * session mid-flight (a refused refresh), not only on [logOut].
   */
  val account: StateFlow<Account?>

  /**
   * Launch restore: tokens? → `GET /me` → `resolveRestore(...)`. Never throws —
   * launch waits on it — so cache I/O inside it is best-effort.
   * Rejected → clears tokens and the cached account.
   */
  suspend fun restore()

  /** `POST /auth/signup`; saves tokens; caches + publishes the account. */
  suspend fun signUp(displayName: String, email: String, password: String): Account

  /** `POST /auth/login`; saves tokens; caches + publishes the account. */
  suspend fun logIn(email: String, password: String): Account

  /** `POST /auth/logout` (errors ignored), then clears tokens + cache; account → null. Never throws. */
  suspend fun logOut()

  /** `DELETE /me` FIRST — if it throws, nothing is cleared. Then same local clear as [logOut]. */
  suspend fun deleteAccount()
}

/** [OnboardingProgressStore.swift] Conformers: `DataStoreOnboardingProgressStore`, `MockOnboardingProgressStore`. */
interface OnboardingProgressStore {
  /** Hot; persisted as one JSON blob, rewritten on every change. */
  val state: StateFlow<OnboardingState>

  suspend fun recordAnswer(questionId: String, optionId: String)
  suspend fun recordMindTree(id: String)
  suspend fun completeOnboarding()
  suspend fun hydrate(quizAnswers: Map<String, String>, mindTree: String?, completed: Boolean)
  suspend fun reset()
}

/** The server's copy of onboarding progress, `GET /me/onboarding`. */
data class OnboardingProfile(
  val quizAnswers: Map<String, String>,
  val mindTree: String?,
  val completed: Boolean,
)

/** [OnboardingRemote.swift] Conformers: `ApiOnboardingRemote`, `MockOnboardingRemote`. */
interface OnboardingRemote {
  /** `GET /onboarding/config` — one attempt; the coordinator owns the retry schedule. */
  suspend fun fetchConfig(): OnboardingConfig

  /** `GET /me/onboarding` (auth). */
  suspend fun fetchProfile(): OnboardingProfile

  /** `PUT /me/onboarding` with the FULL state (the server replaces answers + tree wholesale). */
  suspend fun submit(state: OnboardingState)
}
