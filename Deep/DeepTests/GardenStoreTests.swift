import Testing
import Foundation
@testable import Deep

/// The garden store's contract: server refresh adopts and persists, awards
/// reconcile by absolute set, plant switches are optimistic with a revert, and
/// the wallet riding the garden fetch reaches the hearts sink.
@MainActor
struct GardenStoreTests {
  /// A fresh, empty `UserDefaults` suite scoped to one test, with its name
  /// returned so the caller can tear it down (the `PracticeDefaultsStoreTests`
  /// pattern).
  private static func makeSuite() -> (defaults: UserDefaults, name: String) {
    let name = "DeepTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return (defaults, name)
  }

  // MARK: - Refresh & persistence

  @Test("Refresh adopts the server snapshot and persists it for a cold launch")
  func refreshAdoptsAndPersists() async {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }

    let remote = MockRewardsRemote(sunlightByPlant: [Plant.oakFixture.id: 260])
    let store = GardenStore(remote: remote, defaults: defaults)
    #expect(store.growth == nil) // Nothing persisted yet.

    await store.refresh()
    #expect(store.plant?.id == "oak")
    #expect(store.sunlight == 260)
    #expect(store.growth?.stageIndex == 1)

    // A second instance on the same suite renders offline from the blob.
    let cold = GardenStore(remote: MockRewardsRemote(), defaults: defaults)
    #expect(cold.plant?.id == "oak")
    #expect(cold.sunlight == 260)
  }

  @Test("A failed refresh keeps the persisted snapshot untouched")
  func failedRefreshKeepsSnapshot() async {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }

    let remote = MockRewardsRemote()
    let store = GardenStore(remote: remote, defaults: defaults)
    await store.refresh()

    remote.failsGarden = true
    remote.sunlightByPlant[Plant.oakFixture.id] = 9_999
    await store.refresh()

    #expect(store.sunlight == 240)
    #expect(store.isRefreshing == false)
  }

  @Test("The wallet riding the garden fetch reaches the hearts sink")
  func refreshForwardsWallet() async {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }

    let store = GardenStore(remote: MockRewardsRemote(), defaults: defaults)
    var received: [HeartsSummary] = []
    store.heartsChanged = { received.append($0) }

    await store.refresh()
    #expect(received == [.sample])
  }

  // MARK: - Awards

  @Test("Applying a grant with an absolute reconciles an optimistic tick, never doubles it")
  func applyReconcilesAbsolutes() {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }

    let store = GardenStore(remote: MockRewardsRemote(), defaults: defaults)
    store.seed(plant: .oakFixture, sunlight: 240)

    #expect(store.creditSunlight(1) == 1) // The completion beat's optimistic tick.
    #expect(store.sunlight == 241)

    store.apply(AwardGrant(hearts: 1, sunlight: 1, plantId: "oak", plantSunlight: 241))
    #expect(store.sunlight == 241)
    #expect(store.sunlightByPlant["oak"] == 241)
  }

  @Test("A grant for an unselected plant only moves that plant's tally")
  func applyToUnselectedPlant() {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }

    let store = GardenStore(remote: MockRewardsRemote(), defaults: defaults)
    store.seed(plant: .oakFixture, sunlight: 240)

    store.apply(AwardGrant(hearts: 1, sunlight: 1, plantId: "sakura", plantSunlight: 12))

    #expect(store.sunlight == 240)
    #expect(store.sunlightByPlant["sakura"] == 12)
  }

  @Test("Credit without a plant is a quiet no-op")
  func creditWithoutPlant() {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }

    let store = GardenStore(remote: MockRewardsRemote(), defaults: defaults)
    #expect(store.creditSunlight(1) == 0)
    #expect(store.sunlight == 0)
  }

  // MARK: - Plant switching

  @Test("Switching plants adopts immediately and resumes the new plant's sunlight")
  func selectPlantOptimistic() async {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }

    let remote = MockRewardsRemote(
      sunlightByPlant: [Plant.oakFixture.id: 240, Plant.sakuraFixture.id: 90]
    )
    let store = GardenStore(remote: remote, defaults: defaults)
    await store.refresh()

    await store.selectPlant(.sakuraFixture)
    #expect(store.plant?.id == "sakura")
    #expect(store.sunlight == 90)
    #expect(store.switchFailure == nil)
    #expect(remote.selectedPlantID == "sakura")
  }

  @Test("A refused switch reverts to the previous plant with a quiet caption")
  func selectPlantReverts() async {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }

    let remote = MockRewardsRemote()
    let store = GardenStore(remote: remote, defaults: defaults)
    await store.refresh()

    remote.failsSelectPlant = true
    await store.selectPlant(.sakuraFixture)

    #expect(store.plant?.id == "oak")
    #expect(store.sunlight == 240)
    #expect(store.switchFailure != nil)
  }
}
