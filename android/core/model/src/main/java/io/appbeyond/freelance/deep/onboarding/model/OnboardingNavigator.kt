package io.appbeyond.freelance.deep.onboarding.model

/** Ported from `OnboardingRoute.swift`. */
sealed interface OnboardingRoute {
  data class Quiz(val index: Int) : OnboardingRoute
  data object MindTree : OnboardingRoute
  data object CreateAccount : OnboardingRoute
  data object SignUp : OnboardingRoute
  data object LogIn : OnboardingRoute
  data object CraftingSpace : OnboardingRoute
}

enum class NavDirection { Forward, Backward }

/**
 * The coordinator's whole navigation state. An empty [stack] is the welcome screen.
 * [pending] holds a Quiz route requested before the config loaded; it is replayed by
 * [OnboardingNavigator.configLoaded].
 */
data class OnboardingNav(
  val stack: List<OnboardingRoute> = emptyList(),
  val pending: OnboardingRoute? = null,
  val direction: NavDirection = NavDirection.Forward,
) {
  val current: OnboardingRoute? get() = stack.lastOrNull()
}

/**
 * Pure reducer ported from `OnboardingCoordinatorView.advance(to:)` / `goBack()`, with
 * the week-2 loop fix described on [advance].
 */
object OnboardingNavigator {

  /**
   * Rules, checked in order:
   *  - [to] is a Quiz route and ![configLoaded] → store as [OnboardingNav.pending], stack unchanged.
   *  - [to] is already the top of the stack → unchanged.
   *  - [to] is CreateAccount and [signedIn] → push CraftingSpace instead (the week-2 loop
   *    fix: a signed-in member finishing the quiz never meets the account gate again).
   *  - [to] is Quiz and the current top is LogIn → stack REPLACED with `[to]`, so back from
   *    the first question returns to welcome rather than a stale login form.
   *  - otherwise: push [to].
   * Every branch but the first sets [OnboardingNav.direction] to Forward.
   */
  fun advance(nav: OnboardingNav, to: OnboardingRoute, configLoaded: Boolean, signedIn: Boolean): OnboardingNav {
    if (to is OnboardingRoute.Quiz && !configLoaded) {
      return nav.copy(pending = to)
    }
    if (to == nav.current) {
      return nav
    }
    if (to == OnboardingRoute.CreateAccount && signedIn) {
      return nav.copy(stack = nav.stack + OnboardingRoute.CraftingSpace, direction = NavDirection.Forward)
    }
    if (to is OnboardingRoute.Quiz && nav.current == OnboardingRoute.LogIn) {
      return nav.copy(stack = listOf(to), direction = NavDirection.Forward)
    }
    return nav.copy(stack = nav.stack + to, direction = NavDirection.Forward)
  }

  /** A no-op on the welcome screen (empty stack) and on CraftingSpace — its crafting can't be backed out of. */
  fun back(nav: OnboardingNav): OnboardingNav {
    if (nav.stack.isEmpty() || nav.current == OnboardingRoute.CraftingSpace) {
      return nav
    }
    return nav.copy(stack = nav.stack.dropLast(1), direction = NavDirection.Backward)
  }

  /** Replays [OnboardingNav.pending] through [advance] with the same rules, then clears it. A no-op when nothing is pending. */
  fun configLoaded(nav: OnboardingNav, signedIn: Boolean): OnboardingNav {
    val pending = nav.pending ?: return nav
    return advance(nav.copy(pending = null), pending, configLoaded = true, signedIn = signedIn)
  }

  /** Chrome (back button + progress row) shows when the stack is non-empty and top isn't CraftingSpace. */
  fun showsChrome(nav: OnboardingNav): Boolean =
    nav.stack.isNotEmpty() && nav.current != OnboardingRoute.CraftingSpace
}

// MARK: - Progress [OnboardingCoordinatorView progress]

/** fraction in 0..1, and step/total for the "%d of %d" label. */
data class OnboardingProgress(val step: Int, val total: Int) {
  val fraction: Float get() = if (total == 0) 0f else step.toFloat() / total
}

/**
 * total = questionCount + 1. Quiz(i) → step i+1; MindTree → step total.
 * Any other route (or welcome) → null (no progress shown).
 */
fun onboardingProgress(route: OnboardingRoute?, questionCount: Int): OnboardingProgress? {
  val total = questionCount + 1
  return when (route) {
    is OnboardingRoute.Quiz -> OnboardingProgress(step = route.index + 1, total = total)
    OnboardingRoute.MindTree -> OnboardingProgress(step = total, total = total)
    else -> null
  }
}

// MARK: - Config retry [OnboardingCoordinatorView ConfigLoad]

/** Delays before each attempt at `GET /onboarding/config`: 0, 1 s, 3 s; then failed. */
val ConfigRetryDelaysMillis: List<Long> = listOf(0L, 1_000L, 3_000L)
