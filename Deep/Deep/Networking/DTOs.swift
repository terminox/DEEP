import Foundation

/// Wire shapes for the Deep API. These mirror the backend's JSON exactly
/// (camelCase, so no key strategy needed) and are mapped into the app's domain
/// models by each repository — keeping transport concerns out of the UI types.

// MARK: - Errors

struct APIErrorEnvelope: Decodable {
  struct Body: Decodable {
    let code: String
    let message: String
  }
  let error: Body
}

// MARK: - Request bodies
// Typed so they encode as concrete Encodable values — passing a dictionary
// literal where `any Encodable` is expected makes Swift infer `[String: Any]`,
// which is not Encodable.

struct SignupRequestDTO: Encodable {
  let email: String
  let password: String
  let displayName: String
}

struct LoginRequestDTO: Encodable {
  let email: String
  let password: String
}

struct RefreshRequestDTO: Encodable {
  let refreshToken: String
}

struct OnboardingPutDTO: Encodable {
  let quizAnswers: [String: String]
  let mindTree: String?
  let completed: Bool
}

// MARK: - Auth

struct UserDTO: Decodable {
  let id: String
  let email: String
  let displayName: String
  let role: String
}

struct AuthResponseDTO: Decodable {
  let user: UserDTO
  let accessToken: String
  let refreshToken: String
  let expiresIn: Int
}

struct TokenResponseDTO: Decodable {
  let accessToken: String
  let refreshToken: String
  let expiresIn: Int
}

struct MeResponseDTO: Decodable {
  let user: UserDTO
}

struct OKResponseDTO: Decodable {
  let ok: Bool?
}

// MARK: - Onboarding

struct OnboardingConfigDTO: Decodable {
  struct Option: Decodable {
    let id: String
    let title: String
    let subtitle: String?
    let palette: String
  }
  struct Question: Decodable {
    let id: String
    let prompt: String
    let options: [Option]
  }
  struct Tree: Decodable {
    let id: String
    let name: String
    let tagline: String
    let imageUrl: String?
    let palette: String
  }
  let questions: [Question]
  let mindTrees: [Tree]
}

struct OnboardingProfileDTO: Decodable {
  let quizAnswers: [String: String]
  let mindTree: String?
  let completed: Bool
}

// MARK: - Deep Sound

struct TrackDTO: Decodable {
  let id: String
  let title: String
  let durationSeconds: Int
  let kind: String // INSTRUMENTAL | GUIDED
  let audioUrl: String?
  let isPremium: Bool
  let displayOrder: Int
  let lyricsLanguages: [String]?
}

struct CollectionDTO: Decodable {
  let id: String
  let categoryId: String
  let title: String
  let subtitle: String
  let palette: String
  let imageUrl: String?
  let isPremium: Bool
  let displayOrder: Int
  let trackCount: Int?
  let tracks: [TrackDTO]?
}

struct CategoryDTO: Decodable {
  let id: String
  let slug: String
  let title: String
  let displayOrder: Int
  let collections: [CollectionDTO]?
}

struct SoundHomeDTO: Decodable {
  let categories: [CategoryDTO]
}

struct CollectionDetailDTO: Decodable {
  let collection: CollectionDTO
}

// MARK: - Global Pause home

struct PauseSectionDTO: Decodable {
  let key: String
  let title: String
  let personalized: Bool?
  let collections: [CollectionDTO]
}

struct PauseHomeDTO: Decodable {
  let sections: [PauseSectionDTO]
  let categories: [CategoryDTO]
}

struct LyricsDTO: Decodable {
  let id: String
  let trackId: String
  let languageCode: String
  let content: String
}

struct LyricsResponseDTO: Decodable {
  let lyrics: [LyricsDTO]
}

// MARK: - Practice

struct PracticeSessionDTO: Codable {
  let id: String
  let title: String
  let durationSeconds: Int
  let completedAt: String
}

struct PracticeSyncRequestDTO: Encodable {
  let sessions: [PracticeSessionDTO]
}

struct PracticeSyncResponseDTO: Decodable {
  let synced: [String]
}

struct PracticeSessionsResponseDTO: Decodable {
  let sessions: [PracticeSessionDTO]
}
