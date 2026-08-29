import SwiftUI
import Observation

/// The saved sounds, shared by every screen that can save one.
///
/// A reference type so the bookmark in Now Playing, the long-press menu in a
/// collection, and the You tab's list are all reading one truth — saving a
/// sound anywhere fills the mark everywhere at once. Injected through the
/// environment, mirroring `\.heartLedger`.
///
/// The snapshot persists as one JSON blob (the `GardenStore` pattern), so an
/// offline cold launch opens on the saved sounds instead of an empty state.
/// Refresh flags live here rather than in view `@State`: flipping view state
/// that the refreshing body reads cancels the in-flight refresh.
@MainActor
@Observable
final class PlaylistStore {
  private static let key = "deep.playlist.state"

  /// Every playlist the listener has. One today; the array is what makes a
  /// second one an addition rather than a reshape.
  private(set) var playlists: [Playlist] = []
  private(set) var isRefreshing = false
  /// True only when there is nothing to show *and* the last fetch failed —
  /// a cached snapshot on screen is worth more than an error.
  private(set) var loadFailed = false
  /// False until the first fetch settles, so the list can breathe a skeleton
  /// rather than flash the empty state on launch.
  private(set) var hasLoaded = false

  /// The listener's playlist. Falls back to the first list so a server that
  /// somehow marked none as default still shows something.
  var playlist: Playlist? {
    playlists.first(where: \.isDefault) ?? playlists.first
  }

  var entries: [PlaylistEntry] { playlist?.entries ?? [] }

  /// Track ids currently saved — what every bookmark reads, so the glyph costs
  /// a set lookup rather than a scan of the list.
  private(set) var savedTrackIDs: Set<String> = []

  @ObservationIgnored private let remote: (any PlaylistRemote)?
  @ObservationIgnored private let defaults: UserDefaults
  /// The most recent save/remove round trip — tests await it to make the
  /// reconcile/rollback deterministic.
  @ObservationIgnored private(set) var pendingChange: Task<Void, Never>?

  /// Only a store with a backend keeps a snapshot on disk. A store without one
  /// is a fixture — previews and tests must neither read the real listener's
  /// playlist nor write over it.
  private var persists: Bool { remote != nil }

  init(remote: (any PlaylistRemote)? = nil, defaults: UserDefaults = .standard) {
    self.remote = remote
    self.defaults = defaults
    if remote != nil,
       let data = defaults.data(forKey: Self.key),
       let cached = try? JSONDecoder().decode([Playlist].self, from: data) {
      adopt(cached, persist: false)
      hasLoaded = true
    }
  }

  // MARK: - Reading

  func isSaved(_ track: SoundTrack) -> Bool {
    savedTrackIDs.contains(track.id)
  }

  /// Pulls the playlists. Errors are swallowed while something is already on
  /// screen — the cached snapshot stays and the next refresh retries.
  func refresh() async {
    guard let remote, !isRefreshing else { return }
    isRefreshing = true
    defer {
      isRefreshing = false
      hasLoaded = true
    }
    do {
      let fetched = try await remote.fetchPlaylists()
      loadFailed = false
      withAnimation(.bloom) { adopt(fetched) }
    } catch {
      loadFailed = playlists.isEmpty
    }
  }

  /// The first look on entering the tab; later visits keep what's on screen
  /// and leave refreshing to the pull gesture and the foreground seam.
  func refreshIfNeeded() async {
    guard !hasLoaded else { return }
    await refresh()
  }

  // MARK: - Saving

  /// Saves a sound to the playlist, or takes it out if it's already there.
  ///
  /// Optimistic: the list moves immediately, then the round trip reconciles
  /// against the playlist the server answers with, or rolls the change back.
  /// Without a remote (previews) the change stays purely local.
  func toggle(_ track: SoundTrack, from collection: SoundCollection) {
    if isSaved(track) {
      remove(track)
    } else {
      save(track, from: collection)
    }
  }

  func save(_ track: SoundTrack, from collection: SoundCollection) {
    guard let list = playlist, !isSaved(track) else { return }

    let entry = PlaylistEntry(
      // A placeholder id until the server's lands with the reconcile — it only
      // has to be unique within the list for the duration of the round trip.
      id: "pending-\(track.id)",
      track: track,
      collection: collection,
      savedAt: .now
    )
    withAnimation(.exhale) { insertEntry(entry, into: list.id) }

    guard let remote else { return }
    pendingChange = Task { [weak self] in
      do {
        let settled = try await remote.save(trackId: track.id, in: list.id)
        self?.reconcile(settled)
      } catch {
        self?.rollbackSave(of: track, in: list.id)
      }
    }
  }

  func remove(_ track: SoundTrack) {
    guard let list = playlist,
          let removed = list.entries.first(where: { $0.track.id == track.id })
    else { return }
    withAnimation(.exhale) { removeEntry(track.id, from: list.id) }

    guard let remote else { return }
    pendingChange = Task { [weak self] in
      do {
        let settled = try await remote.remove(trackId: track.id, from: list.id)
        self?.reconcile(settled)
      } catch {
        self?.rollbackRemove(of: removed, in: list.id)
      }
    }
  }

  /// Takes a sound out from the playlist screen, where the entry is what the
  /// row holds.
  func remove(_ entry: PlaylistEntry) {
    remove(entry.track)
  }

  /// Forgets the signed-out account's playlist, so the next listener never
  /// sees a previous one's saved sounds while their first fetch is in flight.
  func resetLocalState() {
    playlists = []
    savedTrackIDs = []
    loadFailed = false
    hasLoaded = false
    defaults.removeObject(forKey: Self.key)
  }

  // MARK: - Book-keeping

  private func adopt(_ fetched: [Playlist], persist: Bool = true) {
    playlists = fetched
    savedTrackIDs = Set(fetched.flatMap { $0.entries.map(\.track.id) })
    guard persist, persists else { return }
    if let data = try? JSONEncoder().encode(fetched) {
      defaults.set(data, forKey: Self.key)
    }
  }

  /// Adopts the server's version of one playlist — normally identical to the
  /// optimistic one, so nothing visibly moves.
  private func reconcile(_ settled: Playlist) {
    guard let index = playlists.firstIndex(where: { $0.id == settled.id }) else { return }
    var updated = playlists
    updated[index] = settled
    withAnimation(.exhale) { adopt(updated) }
  }

  private func insertEntry(_ entry: PlaylistEntry, into playlistID: String) {
    guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
    var updated = playlists
    updated[index].entries.insert(entry, at: 0)
    adopt(updated)
  }

  private func removeEntry(_ trackID: String, from playlistID: String) {
    guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
    var updated = playlists
    updated[index].entries.removeAll { $0.track.id == trackID }
    adopt(updated)
  }

  private func rollbackSave(of track: SoundTrack, in playlistID: String) {
    withAnimation(.exhale) { removeEntry(track.id, from: playlistID) }
  }

  /// Puts a removed sound back where it was, so a failed round trip doesn't
  /// quietly reorder the list.
  private func rollbackRemove(of entry: PlaylistEntry, in playlistID: String) {
    guard let index = playlists.firstIndex(where: { $0.id == playlistID }),
          !playlists[index].entries.contains(where: { $0.track.id == entry.track.id })
    else { return }
    var updated = playlists
    let slot = updated[index].entries.firstIndex { $0.savedAt < entry.savedAt }
      ?? updated[index].entries.endIndex
    updated[index].entries.insert(entry, at: slot)
    withAnimation(.exhale) { adopt(updated) }
  }
}

extension PlaylistStore {
  /// A playlist with sounds in it, for previews of the loaded state.
  static var sample: PlaylistStore {
    let store = PlaylistStore()
    store.adopt([PlaylistFixtures.saved], persist: false)
    store.hasLoaded = true
    return store
  }

  /// Nothing saved yet — the invitation state.
  static var empty: PlaylistStore {
    let store = PlaylistStore()
    store.adopt([PlaylistFixtures.empty], persist: false)
    store.hasLoaded = true
    return store
  }

  /// Still fetching — the breathing skeleton.
  static var loading: PlaylistStore {
    PlaylistStore()
  }

  /// Nothing cached and the fetch refused — the retry state.
  static var failed: PlaylistStore {
    let store = PlaylistStore()
    store.loadFailed = true
    store.hasLoaded = true
    return store
  }
}

extension EnvironmentValues {
  /// The listener's saved sounds. `AppRootView` injects the live store; the
  /// default keeps previews hermetic.
  @Entry var playlistStore: PlaylistStore = PlaylistStore()
}
