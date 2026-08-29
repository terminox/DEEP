import Foundation

/// The backend seam for saved sounds. `PlaylistStore` depends on this protocol
/// so previews and tests run against `MockPlaylistRemote` with no network —
/// the `RewardsRemote` pattern.
///
/// Every call is keyed by playlist id even though a listener has one playlist
/// today, so a second list needs nothing here but a caller.
@MainActor
protocol PlaylistRemote: AnyObject {
  /// Every playlist with its items. One call — the payload is a handful of
  /// rows, so there is nothing to page.
  func fetchPlaylists() async throws -> [Playlist]
  /// Saves a sound. Idempotent server-side; answers with the whole playlist.
  func save(trackId: String, in playlistId: String) async throws -> Playlist
  /// Takes one out. Also idempotent, and also answers with the playlist.
  func remove(trackId: String, from playlistId: String) async throws -> Playlist
}

// MARK: - API

@MainActor
final class APIPlaylistRemote: PlaylistRemote {
  private let client: APIClient

  init(client: APIClient) {
    self.client = client
  }

  func fetchPlaylists() async throws -> [Playlist] {
    let dto: PlaylistsResponseDTO = try await client.request("/me/playlists")
    return dto.playlists.map(Self.playlist(from:))
  }

  func save(trackId: String, in playlistId: String) async throws -> Playlist {
    let dto: PlaylistResponseDTO = try await client.request(
      "/me/playlists/\(playlistId)/items",
      method: "POST",
      body: SaveTrackRequestDTO(trackId: trackId)
    )
    return Self.playlist(from: dto.playlist)
  }

  func remove(trackId: String, from playlistId: String) async throws -> Playlist {
    let dto: PlaylistResponseDTO = try await client.request(
      "/me/playlists/\(playlistId)/items/\(trackId)",
      method: "DELETE"
    )
    return Self.playlist(from: dto.playlist)
  }

  // MARK: Mapping

  /// Tracks and collections map through `APISoundContentRepository`'s existing
  /// projections, so a saved sound is the same domain value the rest of Deep
  /// Sound plays.
  static func playlist(from dto: PlaylistDTO) -> Playlist {
    Playlist(
      id: dto.id,
      name: dto.name,
      isDefault: dto.isDefault,
      entries: (dto.items ?? []).map(entry(from:))
    )
  }

  static func entry(from dto: PlaylistItemDTO) -> PlaylistEntry {
    PlaylistEntry(
      id: dto.id,
      track: APISoundContentRepository.track(from: dto.track),
      collection: APISoundContentRepository.collection(from: dto.collection),
      savedAt: date(from: dto.savedAt) ?? .now
    )
  }

  // The API sends fractional-second ISO timestamps; parse with those and fall
  // back to the plain form, mirroring `APIPracticeRemote`.

  private static let isoFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  private static let plainISOFormatter = ISO8601DateFormatter()

  private static func date(from string: String) -> Date? {
    isoFormatter.date(from: string) ?? plainISOFormatter.date(from: string)
  }
}

// MARK: - Mock

/// Hermetic stand-in for previews and tests: an in-memory playlist that
/// behaves like the server (idempotent saves, whole-playlist answers), with
/// per-call failure switches for exercising the rollback paths.
@MainActor
final class MockPlaylistRemote: PlaylistRemote {
  struct Failure: Error {}

  var playlists: [Playlist]
  /// The next matching call throws.
  var failsFetch = false
  var failsSave = false
  var failsRemove = false

  init(playlists: [Playlist] = [PlaylistFixtures.saved]) {
    self.playlists = playlists
  }

  func fetchPlaylists() async throws -> [Playlist] {
    if failsFetch { throw Failure() }
    return playlists
  }

  func save(trackId: String, in playlistId: String) async throws -> Playlist {
    if failsSave { throw Failure() }
    guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else {
      throw Failure()
    }
    if !playlists[index].entries.contains(where: { $0.track.id == trackId }),
       let found = PlaylistFixtures.everyTrack.first(where: { $0.track.id == trackId }) {
      playlists[index].entries.insert(
        PlaylistEntry(
          id: "item-\(trackId)",
          track: found.track,
          collection: found.collection,
          savedAt: .now
        ),
        at: 0
      )
    }
    return playlists[index]
  }

  func remove(trackId: String, from playlistId: String) async throws -> Playlist {
    if failsRemove { throw Failure() }
    guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else {
      throw Failure()
    }
    playlists[index].entries.removeAll { $0.track.id == trackId }
    return playlists[index]
  }
}
