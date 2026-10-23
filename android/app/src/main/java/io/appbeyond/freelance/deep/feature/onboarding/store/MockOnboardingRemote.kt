package io.appbeyond.freelance.deep.feature.onboarding.store

import io.appbeyond.freelance.deep.onboarding.model.MindTree
import io.appbeyond.freelance.deep.onboarding.model.OnboardingConfig
import io.appbeyond.freelance.deep.onboarding.model.OnboardingState
import io.appbeyond.freelance.deep.onboarding.model.QuizOption
import io.appbeyond.freelance.deep.onboarding.model.QuizQuestion

/**
 * In-memory [OnboardingRemote] for previews — serves [OnboardingConfig.fixture],
 * never the network. The Android twin of `MockOnboardingRemote.swift`.
 */
class MockOnboardingRemote : OnboardingRemote {

  override suspend fun fetchConfig(): OnboardingConfig = OnboardingConfig.fixture

  override suspend fun fetchProfile(): OnboardingProfile =
    OnboardingProfile(quizAnswers = emptyMap(), mindTree = null, completed = false)

  override suspend fun submit(state: OnboardingState) {}
}

/**
 * Bundled sample content for previews only, copied from `QuizQuestion.swift`
 * and `MindTree.swift`. Never a runtime fallback: a failed
 * `GET /onboarding/config` is a state the coordinator shows and retries, not
 * something this fixture papers over — see [OnboardingConfig]'s own doc.
 */
val OnboardingConfig.Companion.fixture: OnboardingConfig
  get() = OnboardingConfig(
    questions = listOf(
      QuizQuestion(
        id = "arrival",
        prompt = "What brings you here today?",
        options = listOf(
          QuizOption(id = "slow-down", title = "To slow down", subtitle = null, palette = "tide"),
          QuizOption(id = "clarity", title = "To find clarity", subtitle = null, palette = "mist"),
          QuizOption(id = "recharge", title = "To recharge", subtitle = null, palette = "ember"),
          QuizOption(id = "exploring", title = "Just exploring", subtitle = null, palette = "bloom"),
        ),
      ),
      QuizQuestion(
        id = "longing",
        prompt = "What do you long for right now?",
        options = listOf(
          QuizOption(id = "calm", title = "Calm", subtitle = null, palette = "tide"),
          QuizOption(id = "connection", title = "Connection", subtitle = null, palette = "dusk"),
          QuizOption(id = "clarity", title = "Clarity", subtitle = null, palette = "mist"),
          QuizOption(id = "healing", title = "Healing", subtitle = null, palette = "bloom"),
        ),
      ),
    ),
    mindTrees = listOf(
      MindTree(
        id = "oak",
        name = "Oak",
        tagline = "Steady & Strong",
        imageUrl = "https://images.unsplash.com/photo-1502082553048-f009c37129b9?w=800&q=80&fm=jpg&fit=crop",
        palette = "tide",
      ),
      MindTree(
        id = "sakura",
        name = "Sakura",
        tagline = "Gentle & Open",
        imageUrl = "https://images.unsplash.com/photo-1522383225653-ed111181a951?w=800&q=80&fm=jpg&fit=crop",
        palette = "bloom",
      ),
      MindTree(
        id = "lotus",
        name = "Lotus",
        tagline = "Calm & Mindful",
        imageUrl = "https://images.unsplash.com/photo-1474557157379-8aa74a6ef541?w=800&q=80&fm=jpg&fit=crop",
        palette = "mist",
      ),
      MindTree(
        id = "orange",
        name = "Orange",
        tagline = "Warm & Joyful",
        imageUrl = "https://upload.wikimedia.org/wikipedia/commons/thumb/6/65/Bitter_orange_-_Citrus_%C3%97_aurantium_03.jpg/500px-Bitter_orange_-_Citrus_%C3%97_aurantium_03.jpg",
        palette = "ember",
      ),
    ),
  )
