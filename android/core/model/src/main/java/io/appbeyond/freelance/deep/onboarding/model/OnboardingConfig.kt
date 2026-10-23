package io.appbeyond.freelance.deep.onboarding.model

/**
 * Server-driven onboarding content. Ported from
 * Deep/Deep/Features/Onboarding/Models — `OnboardingConfig` / `QuizQuestion` /
 * `MindTree`. All pure: no Android, no JSON, no clock.
 */

/** One answer a question offers. [id] is the option's per-question key — the value sent back. */
data class QuizOption(
  val id: String,
  val title: String,
  val subtitle: String?,
  val palette: String,
)

data class QuizQuestion(
  val id: String,
  val prompt: String,
  val options: List<QuizOption>,
)

data class MindTree(
  val id: String,
  val name: String,
  val tagline: String,
  val imageUrl: String?,
  val palette: String,
)

/** `GET /onboarding/config`. Never faked at runtime — a failed fetch is a state, not a fixture. */
data class OnboardingConfig(
  val questions: List<QuizQuestion>,
  val mindTrees: List<MindTree>,
) {
  companion object {
    val Empty = OnboardingConfig(emptyList(), emptyList())
  }
}
