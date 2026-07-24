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

// MARK: - Global Pause event
// Dates travel as ISO-8601 strings and are parsed in the repository mapping,
// matching the rest of this file (no decoder date strategy is configured).

struct PauseScheduleDTO: Decodable {
  struct Phase: Decodable {
    let key: String // lobby | welcome | meditation | feedback
    let startsAt: String
    let endsAt: String
  }
  struct Intention: Decodable {
    let key: String
    let label: String
  }
  let serverNow: String
  let pauseDate: String
  let timezone: String
  let phases: [Phase]
  let lobbyAudioUrl: String?
  let meditationAudioUrl: String?
  let meditationDurationSeconds: Int
  let welcomeMessages: [String]
  let intentions: [Intention]
}

struct PeaceMessageDTO: Decodable {
  let id: String
  let displayName: String
  let countryISO: String?
  let text: String
  let createdAt: String
}

struct PauseLiveDTO: Decodable {
  struct CountryCount: Decodable {
    let iso: String
    let count: Int
  }
  struct Join: Decodable {
    let iso: String
    let at: String
  }
  let serverNow: String
  let phase: String
  let participantCount: Int
  let byCountry: [CountryCount]
  let recentJoins: [Join]
  let messages: [PeaceMessageDTO]
}

struct PauseMessagesResponseDTO: Decodable {
  let serverNow: String
  let messages: [PeaceMessageDTO]
}

struct PauseMessagePostResponseDTO: Decodable {
  let message: PeaceMessageDTO
  let serverNow: String
}

struct PauseHeartbeatRequestDTO: Encodable {
  let presenceId: String
  let countryISO: String?
}

struct PeaceMessagePostRequestDTO: Encodable {
  let text: String
  let countryISO: String?
}

struct PauseReflectionRequestDTO: Encodable {
  let intention: String?
  let mood: String?
}
