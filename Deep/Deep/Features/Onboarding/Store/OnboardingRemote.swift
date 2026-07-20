import SwiftUI
import Observation

/// A returning user's onboarding as held by the backend.
struct OnboardingProfileData: Equatable {
  var quizAnswers: [String: String]
  var mindTree: String?
  var completed: Bool
}

/// The backend seam for onboarding: fetch the server-driven config, read the
/// signed-in user's saved profile, and push the completed answers. Screens
/// depend on this protocol so they preview against `MockOnboardingRemote`.
protocol OnboardingRemote: AnyObject {
  func fetchConfig() async throws -> OnboardingConfig
  func fetchProfile() async throws -> OnboardingProfileData
  func save(quizAnswers: [String: String], mindTree: String?, completed: Bool) async throws
}

/// Hermetic default for previews — serves the bundled fixtures, no network.
@MainActor
final class MockOnboardingRemote: OnboardingRemote {
  func fetchConfig() async throws -> OnboardingConfig { .fixture }
  func fetchProfile() async throws -> OnboardingProfileData {
    OnboardingProfileData(quizAnswers: [:], mindTree: nil, completed: false)
  }
  func save(quizAnswers: [String: String], mindTree: String?, completed: Bool) async throws {}
}

/// Real implementation over `APIClient`.
@MainActor
final class APIOnboardingRemote: OnboardingRemote {
  private let client: APIClient

  init(client: APIClient) {
    self.client = client
  }

  func fetchConfig() async throws -> OnboardingConfig {
    let dto: OnboardingConfigDTO = try await client.request(
      "/onboarding/config",
      authorized: false
    )
    let questions = dto.questions.map { q in
      QuizQuestion(
        id: q.id,
        prompt: q.prompt,
        options: q.options.map { o in
          QuizOption(
            id: o.id,
            title: o.title,
            subtitle: o.subtitle,
            palette: ArtworkPalette(rawValue: o.palette) ?? .mist
          )
        }
      )
    }
    let trees = dto.mindTrees.map { t in
      MindTree(
        id: t.id,
        name: t.name,
        tagline: t.tagline,
        imageURL: t.imageUrl.flatMap(URL.init(string:)),
        palette: ArtworkPalette(rawValue: t.palette) ?? .mist
      )
    }
    return OnboardingConfig(questions: questions, mindTrees: trees)
  }

  func fetchProfile() async throws -> OnboardingProfileData {
    let dto: OnboardingProfileDTO = try await client.request("/me/onboarding")
    return OnboardingProfileData(
      quizAnswers: dto.quizAnswers,
      mindTree: dto.mindTree,
      completed: dto.completed
    )
  }

  func save(quizAnswers: [String: String], mindTree: String?, completed: Bool) async throws {
    let _: OnboardingProfileDTO = try await client.request(
      "/me/onboarding",
      method: "PUT",
      body: OnboardingPutDTO(quizAnswers: quizAnswers, mindTree: mindTree, completed: completed)
    )
  }
}

extension EnvironmentValues {
  @Entry var onboardingRemote: any OnboardingRemote = MockOnboardingRemote()
}
