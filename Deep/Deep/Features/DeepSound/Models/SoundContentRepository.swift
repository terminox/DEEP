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
/// Playing screen reads lyrics. Screens depend on the protocol so they preview
/// against `FixtureSoundContentRepository` (the bundled `SoundLibrary`).
protocol SoundContentRepository: AnyObject {
  func home() async throws -> [SoundShelf]
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
