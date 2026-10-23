import Testing
import Foundation
@testable import Deep

/// DEEP Premium plants: who may switch to one, that the plant already growing
/// is never taken away, that old caches and old servers still decode, and
/// that the server's premium refusal reads as its own failure.
@MainActor
struct PremiumPlantTests {
  private static func makeSuite() -> (defaults: UserDefaults, name: String) {
    let name = "DeepTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    return (defaults, name)
  }

  // MARK: - The gate

  @Test("A premium plant is locked for the free plan, open for a member")
  func premiumPlantLock() {
    let moonflower = Plant.moonflowerFixture
    #expect(PremiumGate.isLocked(moonflower, growing: Plant.oakFixture.id, hasPremium: false))
    #expect(!PremiumGate.isLocked(moonflower, growing: Plant.oakFixture.id, hasPremium: true))
    #expect(!PremiumGate.isLocked(.oakFixture, growing: Plant.lotusFixture.id, hasPremium: false))
  }

  @Test("The plant you are growing is never locked, even after a lapse")
  func growingNeverLocked() {
    var lapsed = Plant.moonflowerFixture
    lapsed.isLocked = true
    #expect(!PremiumGate.isLocked(lapsed, growing: lapsed.id, hasPremium: false))
  }

  @Test("The server's plant verdict beats the client rule")
  func serverPlantVerdict() {
    var grandfathered = Plant.moonflowerFixture
    grandfathered.isLocked = false
    #expect(!PremiumGate.isLocked(grandfathered, growing: nil, hasPremium: false))
  }

  // MARK: - Decoding

  @Test("A garden blob cached before premium plants existed still decodes")
  func legacyGardenBlobDecodes() {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }
    let legacy = """
    {"plant":{"id":"oak","name":"Oak","tagline":"Steady, patient strength","palette":"mist",
    "stages":[{"id":"oak-stage-0","name":"Oak Seedling","threshold":0}]},
    "sunlight":240,"sunlightByPlant":{"oak":240}}
    """
    defaults.set(Data(legacy.utf8), forKey: "deep.garden.state")

    let store = GardenStore(remote: MockRewardsRemote(), defaults: defaults)
    #expect(store.plant?.id == "oak")
    #expect(store.plant?.isPremium == false)
    #expect(store.plant?.isLocked == nil)
    #expect(store.sunlight == 240)
  }

  @Test("A plant round-trips through the cache with its premium fields")
  func plantRoundTrips() throws {
    var plant = Plant.moonflowerFixture
    plant.isLocked = true
    let decoded = try JSONDecoder().decode(Plant.self, from: JSONEncoder().encode(plant))
    #expect(decoded == plant)
  }

  @Test("An older server's plant, without the premium fields, decodes as free")
  func olderServerPlantDecodes() throws {
    let dto = try JSONDecoder().decode(
      PlantDTO.self,
      from: Data(#"{"id":"oak","name":"Oak","tagline":null,"imageUrl":null,"palette":"mist"}"#.utf8)
    )
    let plant = Plant(dto: dto)
    #expect(!plant.isPremium)
    #expect(plant.isLocked == nil)
  }

  @Test("A current server's plant carries its premium fields")
  func currentServerPlantDecodes() throws {
    let dto = try JSONDecoder().decode(
      PlantDTO.self,
      from: Data(#"{"id":"moonflower","name":"Moonflower","isPremium":true,"isLocked":true}"#.utf8)
    )
    let plant = Plant(dto: dto)
    #expect(plant.isPremium)
    #expect(plant.isLocked == true)
  }

  // MARK: - The server's backstop

  @Test("A premium refusal rolls back with its own failure")
  func premiumRefusal() async {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }
    let remote = MockRewardsRemote(catalog: Plant.fixturesWithPremium)
    remote.failsSelectPlant = true
    remote.selectPlantError = APIError.http(status: 403, code: "premium_locked", message: "This plant is premium")
    let store = GardenStore(remote: remote, defaults: defaults)
    store.seed(plant: .oakFixture, sunlight: 240)

    await store.selectPlant(.moonflowerFixture)
    #expect(store.plant?.id == Plant.oakFixture.id)
    #expect(store.switchFailure == .premiumLocked)
  }

  @Test("An unreachable server is not mistaken for a premium refusal")
  func unreachableRefusal() async {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }
    let remote = MockRewardsRemote()
    remote.failsSelectPlant = true
    remote.selectPlantError = APIError.transport("offline")
    let store = GardenStore(remote: remote, defaults: defaults)
    store.seed(plant: .oakFixture, sunlight: 240)

    await store.selectPlant(.sakuraFixture)
    #expect(store.switchFailure == .unreachable)
  }
}
