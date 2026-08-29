import Testing
import Foundation
@testable import Deep

/// The playlist store's contract: a refresh adopts and persists the saved
/// sounds, saving and removing move the list immediately, and a server that
/// refuses either puts the list back exactly as it was.
@MainActor
struct PlaylistStoreTests {
  /// A fresh, empty `UserDefaults` suite scoped to one test, with its name
  /// returned so the caller can tear it down (the `GardenStoreTests` pattern).
  private static func makeSuite() -> (defaults: UserDefaults, name: String) {
    let name = "DeepTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return (defaults, name)
  }

  /// A store already holding the fixture playlist, on a suite of its own.
  private static func makeStore() async -> (
    store: PlaylistStore, remote: MockPlaylistRemote, defaults: UserDefaults, name: String
  ) {
    let (defaults, name) = makeSuite()
    let remote = MockPlaylistRemote()
    let store = PlaylistStore(remote: remote, defaults: defaults)
    await store.refresh()
    return (store, remote, defaults, name)
  }

  /// A sound that is *not* in `PlaylistFixtures.saved`, so saving it is a real
  /// change rather than a no-op.
  private static var unsaved: SoundQueueEntry {
    let saved = Set(PlaylistFixtures.saved.entries.map(\.track.id))
    return PlaylistFixtures.everyTrack.first { !saved.contains($0.track.id) }!
  }

  // MARK: - Refresh & persistence

  @Test("Refresh adopts the server's playlists and persists them for a cold launch")
  func refreshAdoptsAndPersists() async {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }

    let remote = MockPlaylistRemote()
    let store = PlaylistStore(remote: remote, defaults: defaults)
    #expect(store.entries.isEmpty) // Nothing persisted yet.

    await store.refresh()
    #expect(store.playlist?.isDefault == true)
    #expect(store.entries.count == PlaylistFixtures.saved.entries.count)
    #expect(store.isSaved(PlaylistFixtures.saved.entries[0].track))

    // A second instance on the same suite renders offline from the blob.
    let cold = PlaylistStore(remote: MockPlaylistRemote(), defaults: defaults)
    #expect(cold.entries.count == PlaylistFixtures.saved.entries.count)
    #expect(cold.isSaved(PlaylistFixtures.saved.entries[0].track))
  }

  @Test("A first fetch that fails with nothing cached asks to be retried")
  func failedFirstFetchSurfaces() async {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }

    let remote = MockPlaylistRemote()
    remote.failsFetch = true
    let store = PlaylistStore(remote: remote, defaults: defaults)

    await store.refresh()
    #expect(store.loadFailed)
    #expect(store.hasLoaded)
  }

  @Test("A failed refresh keeps what is already on screen")
  func failedRefreshKeepsSnapshot() async {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }

    let remote = MockPlaylistRemote()
    let store = PlaylistStore(remote: remote, defaults: defaults)
    await store.refresh()
    let saved = store.entries.count

    remote.failsFetch = true
    await store.refresh()
    #expect(store.entries.count == saved)
    // Nothing to retry: the cached list is worth more than an error.
    #expect(!store.loadFailed)
  }

  // MARK: - Saving

  @Test("Saving a sound shows immediately and settles on the server's list")
  func saveIsOptimisticThenReconciles() async {
    let (store, _, defaults, name) = await Self.makeStore()
    defer { defaults.removePersistentDomain(forName: name) }

    let pick = Self.unsaved
    store.save(pick.track, from: pick.collection)
    // The mark fills before the round trip has even started.
    #expect(store.isSaved(pick.track))
    #expect(store.entries.first?.track.id == pick.track.id)

    await store.pendingChange?.value
    #expect(store.isSaved(pick.track))
    // The placeholder id has been replaced by the server's.
    #expect(store.entries.first?.id == "item-\(pick.track.id)")
  }

  @Test("A refused save rolls the sound back out of the list")
  func refusedSaveRollsBack() async {
    let (store, remote, defaults, name) = await Self.makeStore()
    defer { defaults.removePersistentDomain(forName: name) }
    let before = store.entries.count

    remote.failsSave = true
    let pick = Self.unsaved
    store.save(pick.track, from: pick.collection)
    #expect(store.isSaved(pick.track))

    await store.pendingChange?.value
    #expect(!store.isSaved(pick.track))
    #expect(store.entries.count == before)
  }

  @Test("Saving a sound that is already saved does nothing")
  func savingTwiceIsANoOp() async {
    let (store, _, defaults, name) = await Self.makeStore()
    defer { defaults.removePersistentDomain(forName: name) }
    let before = store.entries.count

    let existing = store.entries[0]
    store.save(existing.track, from: existing.collection)
    await store.pendingChange?.value
    #expect(store.entries.count == before)
  }

  // MARK: - Removing

  @Test("Removing a sound takes it out and the server agrees")
  func removeIsOptimisticThenReconciles() async {
    let (store, _, defaults, name) = await Self.makeStore()
    defer { defaults.removePersistentDomain(forName: name) }

    let going = store.entries[1]
    store.remove(going)
    #expect(!store.isSaved(going.track))

    await store.pendingChange?.value
    #expect(!store.isSaved(going.track))
    #expect(!store.entries.contains { $0.track.id == going.track.id })
  }

  @Test("A refused removal puts the sound back where it was")
  func refusedRemovalRestoresPosition() async {
    let (store, remote, defaults, name) = await Self.makeStore()
    defer { defaults.removePersistentDomain(forName: name) }
    let order = store.entries.map(\.track.id)

    remote.failsRemove = true
    let going = store.entries[1]
    store.remove(going)
    #expect(!store.isSaved(going.track))

    await store.pendingChange?.value
    #expect(store.isSaved(going.track))
    // Back in its own slot, not shuffled to the top.
    #expect(store.entries.map(\.track.id) == order)
  }

  // MARK: - Toggle & reset

  @Test("Toggle saves a new sound and removes one already saved")
  func toggleGoesBothWays() async {
    let (store, _, defaults, name) = await Self.makeStore()
    defer { defaults.removePersistentDomain(forName: name) }

    let pick = Self.unsaved
    store.toggle(pick.track, from: pick.collection)
    await store.pendingChange?.value
    #expect(store.isSaved(pick.track))

    store.toggle(pick.track, from: pick.collection)
    await store.pendingChange?.value
    #expect(!store.isSaved(pick.track))
  }

  @Test("Signing out forgets the saved sounds, on screen and on disk")
  func resetForgetsEverything() async {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }

    let store = PlaylistStore(remote: MockPlaylistRemote(), defaults: defaults)
    await store.refresh()
    #expect(!store.entries.isEmpty)

    store.resetLocalState()
    #expect(store.entries.isEmpty)
    #expect(store.savedTrackIDs.isEmpty)
    #expect(!store.hasLoaded)

    // The next account's store must not find the previous one's list.
    let next = PlaylistStore(remote: MockPlaylistRemote(), defaults: defaults)
    #expect(next.entries.isEmpty)
  }

  // MARK: - Fixtures

  @Test("A store with no backend never touches the real snapshot")
  func fixtureStoreStaysInMemory() async {
    let (live, _, defaults, name) = await Self.makeStore()
    defer { defaults.removePersistentDomain(forName: name) }
    #expect(!live.entries.isEmpty) // The blob is on the suite.

    // A remote-less store is a fixture: it neither reads nor writes that blob,
    // so a preview can never show — or overwrite — the real listener's list.
    let fixture = PlaylistStore(defaults: defaults)
    #expect(fixture.entries.isEmpty)

    fixture.save(Self.unsaved.track, from: Self.unsaved.collection)
    let reread = PlaylistStore(remote: MockPlaylistRemote(), defaults: defaults)
    #expect(reread.entries.count == live.entries.count)
  }
}
