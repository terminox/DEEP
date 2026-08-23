import Foundation

/// The user's garden as the server holds it. Rides `GET /me/garden` and the
/// plant-switch response; the wallet piggybacks on the same envelope so one
/// fetch hydrates both stores.
struct GardenSnapshot: Equatable {
  /// The selected plant with its full stage ladder; nil only before the server
  /// has ever assigned one.
  var plant: Plant?
  /// Sunlight banked into the selected plant.
  var sunlight: Int
  /// Lifetime sunlight per plant id — unselected plants keep theirs and
  /// resume where they left off.
  var sunlightByPlant: [String: Int]
  /// The wallet riding the same response, when the server sent one.
  var hearts: HeartsSummary?
}

/// The backend seam for hearts, sunlight and the plant catalog. Stores depend
/// on this protocol so previews and tests run against `MockRewardsRemote`
/// (the `PracticeRemote` pattern).
@MainActor
protocol RewardsRemote: AnyObject {
  func fetchGarden() async throws -> GardenSnapshot
  /// The picker catalog: active, non-premium plants with their stages.
  func fetchPlants() async throws -> [Plant]
  /// Switches the selected plant; sunlight already banked is preserved.
  func selectPlant(id: String) async throws -> GardenSnapshot
  func fetchWallet() async throws -> HeartsSummary
  /// Spends hearts. `id` is a client-generated UUID, so a retry of the same
  /// spend is idempotent server-side.
  func spendHearts(id: UUID, amount: Int, category: String, projectId: String?) async throws -> HeartsSummary
  /// Reports a track played through to its end. `nil` when the server withheld
  /// the award (per-day caps, repeat listens).
  func reportListen(trackId: String) async throws -> AwardGrant?
  /// Claims tonight's pause-attendance award. `nil` when not eligible or
  /// already claimed — the server judges.
  func claimPauseAward() async throws -> AwardGrant?
}

// MARK: - Mock

/// Hermetic default for previews and tests: a small in-memory garden + wallet
/// that behaves like the server (absolute figures on every award), with
/// per-call failure switches for exercising rollback paths.
@MainActor
final class MockRewardsRemote: RewardsRemote {
  struct Failure: Error {}

  var catalog: [Plant]
  var selectedPlantID: String?
  var sunlightByPlant: [String: Int]
  var wallet: HeartsSummary
  private(set) var pauseAwardClaimed = false

  /// Failure switches — the next matching call throws.
  var failsGarden = false
  var failsSelectPlant = false
  var failsSpend = false

  /// Spends the mock has accepted, newest last — lets tests assert the
  /// idempotency id and payload that would have gone over the wire.
  private(set) var spends: [(id: UUID, amount: Int, category: String, projectId: String?)] = []

  init(
    catalog: [Plant] = Plant.fixtures,
    selectedPlantID: String? = Plant.oakFixture.id,
    sunlightByPlant: [String: Int] = [Plant.oakFixture.id: 240],
    wallet: HeartsSummary = .sample
  ) {
    self.catalog = catalog
    self.selectedPlantID = selectedPlantID
    self.sunlightByPlant = sunlightByPlant
    self.wallet = wallet
  }

  private var snapshot: GardenSnapshot {
    let plant = catalog.first { $0.id == selectedPlantID } ?? catalog.first
    return GardenSnapshot(
      plant: plant,
      sunlight: plant.flatMap { sunlightByPlant[$0.id] } ?? 0,
      sunlightByPlant: sunlightByPlant,
      hearts: wallet
    )
  }

  func fetchGarden() async throws -> GardenSnapshot {
    if failsGarden { throw Failure() }
    return snapshot
  }

  func fetchPlants() async throws -> [Plant] { catalog }

  func selectPlant(id: String) async throws -> GardenSnapshot {
    if failsSelectPlant { throw Failure() }
    guard catalog.contains(where: { $0.id == id }) else { throw Failure() }
    selectedPlantID = id
    return snapshot
  }

  func fetchWallet() async throws -> HeartsSummary { wallet }

  func spendHearts(
    id: UUID, amount: Int, category: String, projectId: String?
  ) async throws -> HeartsSummary {
    if failsSpend || wallet.balance < amount { throw Failure() }
    spends.append((id, amount, category, projectId))
    wallet.balance -= amount
    wallet.given += amount
    wallet.givenByCategory[category, default: 0] += amount
    return wallet
  }

  func reportListen(trackId: String) async throws -> AwardGrant? {
    grant(hearts: 1, sunlight: 1)
  }

  func claimPauseAward() async throws -> AwardGrant? {
    guard !pauseAwardClaimed else { return nil }
    pauseAwardClaimed = true
    return grant(hearts: 5, sunlight: 5)
  }

  /// Applies an award to the mock's own books and returns it with absolutes,
  /// exactly the shape the real server sends.
  private func grant(hearts: Int, sunlight: Int) -> AwardGrant? {
    guard wallet.remainingToday >= hearts else { return nil }
    let plantID = selectedPlantID ?? catalog.first?.id
    wallet.balance += hearts
    wallet.earned += hearts
    wallet.earnedToday += hearts
    wallet.remainingToday -= hearts
    if let plantID { sunlightByPlant[plantID, default: 0] += sunlight }
    return AwardGrant(
      hearts: hearts,
      sunlight: sunlight,
      plantId: plantID,
      heartsBalance: wallet.balance,
      heartsEarned: wallet.earned,
      heartsGiven: wallet.given,
      heartsEarnedToday: wallet.earnedToday,
      heartsRemainingToday: wallet.remainingToday,
      plantSunlight: plantID.flatMap { sunlightByPlant[$0] }
    )
  }
}

// MARK: - API

/// Real implementation over `APIClient`, against the reward endpoints
/// (`/me/garden`, `/garden/plants`, `/me/garden/plant`, `/me/wallet`,
/// `/me/hearts/spend`, `/me/sound/listens`, `/me/pause/award`).
@MainActor
final class APIRewardsRemote: RewardsRemote {
  private let client: APIClient

  init(client: APIClient) {
    self.client = client
  }

  func fetchGarden() async throws -> GardenSnapshot {
    let dto: GardenResponseDTO = try await client.request("/me/garden")
    return GardenSnapshot(dto: dto)
  }

  func fetchPlants() async throws -> [Plant] {
    let dto: PlantsResponseDTO = try await client.request("/garden/plants")
    return dto.plants.map { Plant(dto: $0) }
  }

  func selectPlant(id: String) async throws -> GardenSnapshot {
    let dto: GardenResponseDTO = try await client.request(
      "/me/garden/plant",
      method: "PUT",
      body: SelectPlantRequestDTO(plantId: id)
    )
    return GardenSnapshot(dto: dto)
  }

  func fetchWallet() async throws -> HeartsSummary {
    let dto: WalletResponseDTO = try await client.request("/me/wallet")
    return HeartsSummary(dto: dto.wallet)
  }

  func spendHearts(
    id: UUID, amount: Int, category: String, projectId: String?
  ) async throws -> HeartsSummary {
    let dto: WalletResponseDTO = try await client.request(
      "/me/hearts/spend",
      method: "POST",
      body: SpendHeartsRequestDTO(
        id: id.uuidString,
        amount: amount,
        category: category,
        projectId: projectId
      )
    )
    return HeartsSummary(dto: dto.wallet)
  }

  func reportListen(trackId: String) async throws -> AwardGrant? {
    let dto: AwardResponseDTO = try await client.request(
      "/me/sound/listens",
      method: "POST",
      body: ListenRequestDTO(trackId: trackId)
    )
    return AwardGrant(outcomes: [dto.award].compactMap { $0 }, wallet: dto.wallet, plant: dto.plant)
  }

  func claimPauseAward() async throws -> AwardGrant? {
    let dto: PauseAwardResponseDTO = try await client.request(
      "/me/pause/award",
      method: "POST"
    )
    return AwardGrant(outcomes: [dto.award].compactMap { $0 }, wallet: dto.wallet, plant: dto.plant)
  }
}

// MARK: - DTO assembly
// Shared by every award-bearing repository (rewards, practice sync, pause
// messages), so the wire trio always folds into a grant the same way.

extension HeartsSummary {
  init(dto: WalletDTO) {
    self.init(
      balance: dto.heartsBalance,
      earned: dto.heartsEarned ?? 0,
      given: dto.heartsGiven ?? 0,
      earnedToday: dto.earnedToday ?? 0,
      remainingToday: dto.remainingToday ?? 0,
      dailyCap: dto.dailyCap ?? HeartLedger.dailyEarnCeiling,
      givenByCategory: dto.givenByCategory ?? [:]
    )
  }
}

extension PlantStage {
  init(dto: PlantStageDTO) {
    self.init(
      id: dto.id,
      name: dto.name,
      threshold: dto.sunlightRequired,
      mascotURL: dto.mascotUrl.flatMap(URL.init(string:)),
      mascotBgURL: dto.mascotBgUrl.flatMap(URL.init(string:)),
      heroVideoURL: dto.heroVideoUrl.flatMap(URL.init(string:))
    )
  }
}

extension Plant {
  init(dto: PlantDTO, stages: [PlantStageDTO]? = nil) {
    self.init(
      id: dto.id,
      name: dto.name,
      tagline: dto.tagline ?? "",
      imageURL: dto.imageUrl.flatMap(URL.init(string:)),
      palette: dto.palette.flatMap(ArtworkPalette.init(rawValue:)) ?? .mist,
      stages: (dto.stages ?? stages ?? []).map(PlantStage.init(dto:))
    )
  }
}

extension GardenSnapshot {
  init(dto: GardenResponseDTO) {
    self.init(
      // Tolerate the stage ladder arriving either nested in the plant or as
      // the garden's sibling `stages` array.
      plant: dto.garden.selectedPlant.map { Plant(dto: $0, stages: dto.garden.stages) },
      sunlight: dto.garden.sunlight ?? 0,
      sunlightByPlant: dto.garden.sunlightByPlant ?? [:],
      hearts: dto.wallet.map(HeartsSummary.init(dto:))
    )
  }
}

extension AwardGrant {
  /// Folds one or more award outcomes plus the sibling wallet/plant snapshots
  /// into a single grant: deltas summed over the *granted* outcomes, absolutes
  /// taken from the snapshots. `nil` when the response carried nothing to
  /// apply at all (older servers, or nothing granted and no snapshots).
  init?(outcomes: [AwardOutcomeDTO], wallet: WalletDTO?, plant: PlantProgressDTO?) {
    let granted = outcomes.filter { $0.granted == true }
    let capped = outcomes.contains { $0.cappedBy == "daily_cap" }
    guard !granted.isEmpty || capped || wallet != nil || plant != nil else { return nil }
    self.init(
      hearts: granted.reduce(0) { $0 + ($1.heartsGranted ?? 0) },
      sunlight: granted.reduce(0) { $0 + ($1.sunlightGranted ?? 0) },
      plantId: plant?.plantId ?? granted.compactMap(\.plantId).first,
      heartsCapped: capped,
      heartsBalance: wallet?.heartsBalance,
      heartsEarned: wallet?.heartsEarned,
      heartsGiven: wallet?.heartsGiven,
      heartsEarnedToday: wallet?.earnedToday,
      heartsRemainingToday: wallet?.remainingToday,
      plantSunlight: plant?.sunlight,
      plantStageIndex: plant?.currentStageIndex
    )
  }
}
