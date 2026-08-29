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
  // Awards settled by this sync — one outcome per newly-stored session — plus
  // the post-award wallet/plant snapshots. All optional: an older server
  // simply syncs without awarding.
  let awards: [AwardOutcomeDTO]?
  let wallet: WalletDTO?
  let plant: PlantProgressDTO?
}

struct PracticeSessionsResponseDTO: Decodable {
  let sessions: [PracticeSessionDTO]
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
  // The word the message was tagged with. Absent on older servers and on
  // messages left untagged.
  let intention: String?
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
    // Privacy-rounded join coordinates; absent when IP geolocation missed
    // (the client falls back to the country centroid).
    let lat: Double?
    let lon: Double?
  }
  struct Point: Decodable {
    let lat: Double
    let lon: Double
    let count: Int
  }
  let serverNow: String
  let participantCount: Int
  let byCountry: [CountryCount]
  // Continent codes ("AS", "EU", "NA"…) rather than countries. Optional:
  // older servers omit it and the client folds `byCountry` itself.
  let byContinent: [CountryCount]?
  // Server-clustered participant locations (≤96, privacy-rounded). Optional:
  // older servers omit both and the client keeps the country-glow path.
  let points: [Point]?
  let unlocatedByCountry: [CountryCount]?
  let recentJoins: [Join]
}

struct PauseMessagesResponseDTO: Decodable {
  let serverNow: String
  let messages: [PeaceMessageDTO]
  let nextCursor: String?
}

struct PauseMessagePostResponseDTO: Decodable {
  let message: PeaceMessageDTO
  let serverNow: String
  // The first peace message of the night earns an award; every later message
  // (and every older server) omits all three.
  let award: AwardOutcomeDTO?
  let wallet: WalletDTO?
  let plant: PlantProgressDTO?
}

struct PauseHeartbeatRequestDTO: Encodable {
  let presenceId: String
  let countryISO: String?
}

struct PauseHeartbeatResponseDTO: Decodable {
  struct Location: Decodable {
    let lat: Double
    let lon: Double
  }
  // The caller's own resolved (privacy-rounded) location; null when the
  // server couldn't place the IP. Absent entirely on older servers.
  let location: Location?
}

struct PeaceMessagePostRequestDTO: Encodable {
  let text: String
  let countryISO: String?
  let intention: String?
}

struct PauseReflectionRequestDTO: Encodable {
  let intention: String?
  let mood: String?
}

// MARK: - Garden & rewards
// Every award-bearing response carries the same trio: the award outcome(s),
// plus sibling `wallet` and `plant` snapshots with the ABSOLUTE post-award
// figures. All new fields are optional so an older server stays decodable.

struct PlantStageDTO: Decodable {
  let id: String
  let name: String
  /// Cumulative sunlight to REACH this stage; first stage is 0.
  let sunlightRequired: Int
  let mascotUrl: String?
  let mascotBgUrl: String?
  let heroVideoUrl: String?
}

struct PlantDTO: Decodable {
  let id: String
  let name: String
  let tagline: String?
  let imageUrl: String?
  let palette: String?
  let stages: [PlantStageDTO]?
}

struct WalletDTO: Decodable {
  let heartsBalance: Int
  let heartsEarned: Int?
  let heartsGiven: Int?
  let earnedToday: Int?
  let remainingToday: Int?
  let dailyCap: Int?
  let givenByCategory: [String: Int]?
}

/// The credited plant's post-award progress.
struct PlantProgressDTO: Decodable {
  let plantId: String
  let sunlight: Int
  let currentStageIndex: Int?
}

struct AwardOutcomeDTO: Decodable {
  let kind: String?
  let granted: Bool?
  let heartsGranted: Int?
  let sunlightGranted: Int?
  let plantId: String?
  /// Why the award was withheld: "daily_cap" | "kind_cap" | "duplicate".
  let cappedBy: String?
}

struct GardenStateDTO: Decodable {
  let selectedPlant: PlantDTO?
  /// Sunlight banked into the selected plant.
  let sunlight: Int?
  let currentStageIndex: Int?
  /// The selected plant's stages, when not nested inside `selectedPlant`.
  let stages: [PlantStageDTO]?
  /// Lifetime sunlight per plant id — the picker shows every plant at its
  /// own earned stage.
  let sunlightByPlant: [String: Int]?
}

struct GardenResponseDTO: Decodable {
  let garden: GardenStateDTO
  let wallet: WalletDTO?
}

struct PlantsResponseDTO: Decodable {
  let plants: [PlantDTO]
}

struct WalletResponseDTO: Decodable {
  let wallet: WalletDTO
}

struct SelectPlantRequestDTO: Encodable {
  let plantId: String
}

struct SpendHeartsRequestDTO: Encodable {
  /// Client-generated UUID — the idempotency key for a safe retry.
  let id: String
  let amount: Int
  let category: String
  let projectId: String?
}

struct ListenRequestDTO: Encodable {
  let trackId: String
}

/// `POST /me/sound/listens` and any single-award response.
struct AwardResponseDTO: Decodable {
  let award: AwardOutcomeDTO?
  let wallet: WalletDTO?
  let plant: PlantProgressDTO?
}

/// `POST /me/pause/award` — the explicit attendance claim.
struct PauseAwardResponseDTO: Decodable {
  let eligible: Bool?
  let award: AwardOutcomeDTO?
  let wallet: WalletDTO?
  let plant: PlantProgressDTO?
  let serverNow: String?
}

// MARK: - Playlists

/// One saved sound. The origin `collection` arrives without its tracks — a row
/// needs its artwork and its name, nothing more.
struct PlaylistItemDTO: Decodable {
  let id: String
  let savedAt: String
  let track: TrackDTO
  let collection: CollectionDTO
}

struct PlaylistDTO: Decodable {
  let id: String
  let name: String
  let isDefault: Bool
  let trackCount: Int
  let updatedAt: String
  let items: [PlaylistItemDTO]?
}

/// `GET /me/playlists` — every playlist with its items, in one call.
struct PlaylistsResponseDTO: Decodable {
  let playlists: [PlaylistDTO]
}

/// What saving and removing a sound both answer with: the whole playlist,
/// so the client reconciles against server truth rather than guessing.
struct PlaylistResponseDTO: Decodable {
  let playlist: PlaylistDTO
}

// MARK: - Request bodies (playlists)

struct SaveTrackRequestDTO: Encodable {
  let trackId: String
}
