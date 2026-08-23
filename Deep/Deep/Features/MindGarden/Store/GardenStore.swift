import SwiftUI
import Observation

/// The garden's single source of truth: the selected plant, its banked
/// sunlight, the per-plant tallies behind the picker, and the catalog. Server
/// truth arrives through `refresh()`/`apply(_:)`; optimistic credits keep the
/// UI instant and are reconciled by the next absolute figure, never
/// double-counted.
///
/// The whole snapshot persists as one JSON blob (mirroring
/// `PracticeDefaultsStore`), so an offline cold launch still renders the last
/// known garden. Refresh/loading flags live here rather than in view `@State`
/// — flipping view state that the `.refreshable` body reads cancels the
/// in-flight refresh (see the `.heroRefreshable` note).
@MainActor
@Observable
final class GardenStore {
  private static let key = "deep.garden.state"

  /// The persisted shape — everything an offline launch needs to draw.
  private struct GardenBlob: Codable {
    var plant: Plant?
    var sunlight: Int
    var sunlightByPlant: [String: Int]
  }

  /// The selected plant with its stage ladder; nil until the first snapshot
  /// (server or persisted) lands.
  private(set) var plant: Plant?
  /// Sunlight banked into the selected plant, cumulative over its life.
  private(set) var sunlight: Int = 0
  /// Lifetime sunlight per plant id — unselected plants keep theirs.
  private(set) var sunlightByPlant: [String: Int] = [:]
  /// The picker catalog; empty until `loadCatalogIfNeeded()` runs.
  private(set) var catalog: [Plant] = []
  private(set) var isRefreshing = false
  private(set) var isLoadingCatalog = false
  /// Set when a plant switch was rolled back — the picker shows it as a quiet
  /// caption. Cleared on the next attempt.
  private(set) var switchFailure: String?

  /// Wallet snapshots ride the garden fetch; `AppDependencies` points this at
  /// `HeartLedger.hydrate` so one fetch hydrates both stores.
  @ObservationIgnored var heartsChanged: (@MainActor (HeartsSummary) -> Void)?

  /// The derivation everything renders from; nil until a plant is known.
  var growth: GardenGrowth? {
    plant.map { GardenGrowth(plant: $0, sunlight: sunlight) }
  }

  private let remote: any RewardsRemote
  private let defaults: UserDefaults

  init(remote: any RewardsRemote, defaults: UserDefaults = .standard) {
    self.remote = remote
    self.defaults = defaults
    if let data = defaults.data(forKey: Self.key),
       let blob = try? JSONDecoder().decode(GardenBlob.self, from: data) {
      plant = blob.plant
      sunlight = blob.sunlight
      sunlightByPlant = blob.sunlightByPlant
    }
  }

  // MARK: - Server truth

  /// Pulls the garden (and the wallet riding it). Errors are swallowed — the
  /// persisted snapshot is already on screen and the next refresh retries.
  func refresh() async {
    guard !isRefreshing else { return }
    isRefreshing = true
    defer { isRefreshing = false }
    guard let snapshot = try? await remote.fetchGarden() else { return }
    adopt(snapshot)
  }

  /// Fetches the picker catalog once; later calls are free.
  func loadCatalogIfNeeded() async {
    guard catalog.isEmpty, !isLoadingCatalog else { return }
    isLoadingCatalog = true
    defer { isLoadingCatalog = false }
    guard let plants = try? await remote.fetchPlants() else { return }
    catalog = plants
  }

  /// Switches the selected plant — optimistically, resumed at whatever
  /// sunlight it had already earned, reverted with a quiet caption if the
  /// server refuses.
  func selectPlant(_ newPlant: Plant) async {
    guard newPlant.id != plant?.id else { return }
    let previousPlant = plant
    let previousSunlight = sunlight
    switchFailure = nil
    withAnimation(.exhale) {
      plant = newPlant
      sunlight = sunlightByPlant[newPlant.id] ?? 0
    }
    persist()
    do {
      adopt(try await remote.selectPlant(id: newPlant.id))
    } catch {
      withAnimation(.exhale) {
        plant = previousPlant
        sunlight = previousSunlight
        switchFailure = "Couldn't switch plants — try again in a moment."
      }
      persist()
    }
  }

  /// Applies a settled award: absolutes SET the tallies, so the optimistic
  /// tick is reconciled rather than double-counted. Delta fallback only for
  /// responses that carried no snapshot.
  func apply(_ grant: AwardGrant) {
    guard let plantId = grant.plantId else { return }
    withAnimation(.exhale) {
      if let absolute = grant.plantSunlight {
        sunlightByPlant[plantId] = absolute
        if plantId == plant?.id { sunlight = absolute }
      } else if grant.sunlight > 0 {
        sunlightByPlant[plantId, default: 0] += grant.sunlight
        if plantId == plant?.id { sunlight += grant.sunlight }
      }
    }
    persist()
  }

  /// Optimistic credit the moment a practice completes — the halo ticks
  /// instantly; the practice sync's absolute figures reconcile it.
  func creditSunlight(_ amount: Int = 1) {
    guard amount > 0, let plant else { return }
    withAnimation(.exhale) {
      sunlight += amount
      sunlightByPlant[plant.id, default: 0] += amount
    }
    persist()
  }

  /// Forgets everything tied to the signed-out account — the persisted blob
  /// included — so the next account opens on the loading skeleton, never a
  /// previous user's garden. The catalog stays: it is app content, not user
  /// state. Called on sign-out / account deletion.
  func resetLocalState() {
    plant = nil
    sunlight = 0
    sunlightByPlant = [:]
    switchFailure = nil
    defaults.removeObject(forKey: Self.key)
  }

  // MARK: - Internals

  private func adopt(_ snapshot: GardenSnapshot) {
    withAnimation(.exhale) {
      if let plant = snapshot.plant { self.plant = plant }
      sunlight = snapshot.sunlight
      sunlightByPlant = snapshot.sunlightByPlant
    }
    persist()
    if let hearts = snapshot.hearts { heartsChanged?(hearts) }
  }

  private func persist() {
    let blob = GardenBlob(plant: plant, sunlight: sunlight, sunlightByPlant: sunlightByPlant)
    guard let data = try? JSONEncoder().encode(blob) else { return }
    defaults.set(data, forKey: Self.key)
  }
}

// MARK: - Fixtures

extension GardenStore {
  /// Preloads a snapshot without touching the remote — fixture factories and
  /// tests seed known states through this.
  func seed(plant: Plant?, sunlight: Int, sunlightByPlant: [String: Int] = [:]) {
    self.plant = plant
    self.sunlight = sunlight
    self.sunlightByPlant = sunlightByPlant.isEmpty
      ? (plant.map { [$0.id: sunlight] } ?? [:])
      : sunlightByPlant
  }

  /// A store on the mock remote with `state` preloaded, writing to a preview
  /// suite so fixtures never touch the real persisted garden.
  private static func fixture(sunlight: Int) -> GardenStore {
    let store = GardenStore(
      remote: MockRewardsRemote(sunlightByPlant: [Plant.oakFixture.id: sunlight]),
      defaults: UserDefaults(suiteName: "deep.garden.preview") ?? .standard
    )
    store.seed(plant: .oakFixture, sunlight: sunlight)
    return store
  }

  /// A warm mid-journey garden for previews and the environment default.
  static var sample: GardenStore { fixture(sunlight: 240) }

  /// A first-day garden — the seed just planted.
  static var fresh: GardenStore { fixture(sunlight: 0) }

  /// The ceiling state: the oak in its final form.
  static var flourishing: GardenStore { fixture(sunlight: 700) }

  /// A garden still waiting for its first snapshot — no plant, no persisted
  /// blob — so the home's skeleton row can be previewed. The mock's garden
  /// fetch fails, keeping the state empty even if something refreshes it.
  static var loading: GardenStore {
    let remote = MockRewardsRemote()
    remote.failsGarden = true
    return GardenStore(
      remote: remote,
      defaults: UserDefaults(suiteName: "deep.garden.preview.empty") ?? .standard
    )
  }

  /// A picker-ready garden: the whole mock catalog with sunlight banked into
  /// several plants at different stages, the oak selected.
  static var pickerSample: GardenStore {
    let sunlightByPlant = [
      Plant.oakFixture.id: 240,
      Plant.sakuraFixture.id: 480,
      Plant.lotusFixture.id: 0,
    ]
    let store = GardenStore(
      remote: MockRewardsRemote(sunlightByPlant: sunlightByPlant),
      defaults: UserDefaults(suiteName: "deep.garden.preview") ?? .standard
    )
    store.seed(plant: .oakFixture, sunlight: 240, sunlightByPlant: sunlightByPlant)
    return store
  }

  /// A garden whose last plant switch the server refused — the picker's quiet
  /// failure caption.
  static var switchFailed: GardenStore {
    let store = pickerSample
    store.switchFailure = "Couldn't switch plants — try again in a moment."
    return store
  }
}

extension EnvironmentValues {
  /// The shared garden. The shell injects the live store; the mock-backed
  /// default keeps previews hermetic (mirroring `\.heartLedger`).
  @Entry var gardenStore: GardenStore = .sample
}
