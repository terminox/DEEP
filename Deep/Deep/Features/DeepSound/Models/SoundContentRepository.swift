import SwiftUI

/// One home shelf: a titled category and its collections (e.g. "Calm").
struct SoundShelf: Identifiable, Hashable {
  let id: String
  let title: String
  let collections: [SoundCollection]
}

/// A track's lyrics in one language.
struct Lyrics: Identifiable, Hashable {
  var id: String { languageCode }
  let languageCode: String
  let content: String
}

/// The content seam for Deep Sound. The home reads shelves from here; the Now
/// Playing screen reads lyrics; the Global Pause home reads its server-composed
/// sections. Screens depend on the protocol so they preview against
/// `FixtureSoundContentRepository` (the bundled `SoundLibrary`).
protocol SoundContentRepository: AnyObject {
  func home() async throws -> [SoundShelf]
  func pauseHome() async throws -> PauseHome
  func lyrics(trackID: String, language: String?) async throws -> [Lyrics]
}

/// Offline / preview repository serving the bundled fixtures. Also the
/// environment default so previews are hermetic.
@MainActor
final class FixtureSoundContentRepository: SoundContentRepository {
  func home() async throws -> [SoundShelf] {
    [
      SoundShelf(id: "calm", title: "Calm", collections: SoundLibrary.calm),
      SoundShelf(id: "morning", title: "Morning", collections: SoundLibrary.morning),
      SoundShelf(id: "sleep", title: "Sleep", collections: SoundLibrary.sleep),
      SoundShelf(id: "deep-teacher", title: "Deep Teacher", collections: SoundLibrary.deepTeacher),
      SoundShelf(id: "deep-kids", title: "Deep Kids", collections: SoundLibrary.deepKids),
    ]
  }

  func pauseHome() async throws -> PauseHome {
    // Mirrors the backend's composition rules over the bundled fixtures:
    // popular = each group's lead, forYou = each group's second, today = two
    // guided picks plus two instrumentals.
    let groups: [(id: String, title: String, collections: [SoundCollection])] = [
      ("calm", "Calm", SoundLibrary.calm),
      ("morning", "Morning", SoundLibrary.morning),
      ("sleep", "Sleep", SoundLibrary.sleep),
      ("deep-teacher", "Deep Teacher", SoundLibrary.deepTeacher),
      ("deep-kids", "Deep Kids", SoundLibrary.deepKids),
    ]
    return PauseHome(
      sections: [
        PauseHomeSection(
          id: "popular",
          title: "Popular now",
          collections: groups.compactMap { $0.collections.first }
        ),
        PauseHomeSection(
          id: "today",
          title: "Today's sessions",
          collections: Array(SoundLibrary.deepTeacher.prefix(2))
            + [SoundLibrary.calm[2], SoundLibrary.sleep[2]]
        ),
        PauseHomeSection(
          id: "forYou",
          title: "Made for you",
          collections: groups.compactMap { $0.collections.dropFirst().first }
        ),
      ],
      categories: groups.map {
        PauseCategory(id: $0.id, slug: $0.id, title: $0.title, collections: $0.collections)
      }
    )
  }

  func lyrics(trackID: String, language: String?) async throws -> [Lyrics] { [] }
}

/// Real repository over `APIClient`, mapping the wire DTOs into domain models.
@MainActor
final class APISoundContentRepository: SoundContentRepository {
  private let client: APIClient

  init(client: APIClient) {
    self.client = client
  }

  func home() async throws -> [SoundShelf] {
    let dto: SoundHomeDTO = try await client.request("/sound/home", authorized: false)
    return dto.categories.map { cat in
      SoundShelf(
        id: cat.id,
        title: cat.title,
        collections: (cat.collections ?? []).map(Self.collection(from:))
      )
    }
  }

  func pauseHome() async throws -> PauseHome {
    // `authorized: true` attaches the bearer token when signed in so the
    // backend can personalize "Made for you"; the endpoint never 401s, so
    // anonymous users still get the composed fallbacks.
    let dto: PauseHomeDTO = try await client.request("/pause/home", authorized: true)
    return PauseHome(
      sections: dto.sections.map { section in
        PauseHomeSection(
          id: section.key,
          title: section.title,
          collections: section.collections.map(Self.collection(from:))
        )
      },
      categories: dto.categories.map { cat in
        PauseCategory(
          id: cat.id,
          slug: cat.slug,
          title: cat.title,
          collections: (cat.collections ?? []).map(Self.collection(from:))
        )
      }
    )
  }

  func lyrics(trackID: String, language: String?) async throws -> [Lyrics] {
    var path = "/sound/tracks/\(trackID)/lyrics"
    if let language { path += "?lang=\(language)" }
    let dto: LyricsResponseDTO = try await client.request(path, authorized: false)
    return dto.lyrics.map { Lyrics(languageCode: $0.languageCode, content: $0.content) }
  }

  // MARK: - Mapping

  static func collection(from dto: CollectionDTO) -> SoundCollection {
    SoundCollection(
      id: dto.id,
      title: dto.title,
      subtitle: dto.subtitle,
      palette: ArtworkPalette(rawValue: dto.palette) ?? .mist,
      imageURL: dto.imageUrl.flatMap(URL.init(string:)),
      categoryId: dto.categoryId,
      isPremium: dto.isPremium,
      tracks: (dto.tracks ?? []).map(Self.track(from:))
    )
  }

  static func track(from dto: TrackDTO) -> SoundTrack {
    SoundTrack(
      id: dto.id,
      title: dto.title,
      duration: TimeInterval(dto.durationSeconds),
      kind: dto.kind == "GUIDED" ? .guided : .instrumental,
      audioURL: dto.audioUrl.flatMap(URL.init(string:)),
      isPremium: dto.isPremium
    )
  }
}

extension EnvironmentValues {
  /// The Deep Sound content source. Defaults to the bundled fixtures (hermetic
  /// previews); `AppRootView` injects the API-backed repository at runtime.
  @Entry var soundContentRepository: any SoundContentRepository = FixtureSoundContentRepository()
}
