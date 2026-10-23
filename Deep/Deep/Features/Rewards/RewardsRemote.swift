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
  /// Reports a track played through to its end at `completedAt`, so a report
  /// that waited offline still counts on the day it was earned. Throws
  /// `APIError.http(404, …)` for a track the server no longer has.
  func reportListen(trackId: String, completedAt: Date) async throws -> ListenOutcome
  /// Claims tonight's pause-attendance award. The server judges: `eligible`
  /// says whether tonight's attendance counted at all, `grant` carries the
  /// award (nil when ineligible, or already claimed).
  func claimPauseAward() async throws -> PauseAwardClaim
}

/// The server's answer to a pause-attendance claim. Kept apart from the grant
/// because the two can disagree: a night already claimed is still *eligible*
/// (it still counts as a practice day) yet carries no fresh grant, while an
/// ineligible night is the one the ending has to explain honestly.
struct PauseAwardClaim: Equatable {
  /// Whether the server judged tonight's attendance complete. Older servers
  /// that never sent the flag read as eligible — they only ever answered an
  /// ineligible claim with an empty award.
  var eligible: Bool
  var grant: AwardGrant?
}

/// The server's answer to one listen report.
struct ListenOutcome: Equatable {
  /// Whether the server placed the listen on a day at all. False when it
  /// finished too long ago (or too far ahead) to judge — nothing granted,
  /// nothing to retry.
  var judged: Bool
  /// Whether this listen earned its heart.
  var granted: Bool
  /// Why it didn't: "duplicate" (this track already counted today),
  /// "kind_cap" (today's track hearts are all in), "daily_cap" (the day's
  /// overall hearts ceiling).
  var cappedBy: String?
  /// The day's track-heart tally; nil from older servers and unjudged listens.
  var tally: ListenTally?
  /// The settled grant for the ledger and garden — deltas plus the server's
  /// absolute figures. Nil only when the response carried nothing to apply.
  var grant: AwardGrant?
}

/// How many track hearts a day has earned, against its allowance.
struct ListenTally: Equatable {
  /// The local day the listen counted toward ("YYYY-MM-DD").
  var dayKey: String
  var earned: Int
  var perDay: Int

  var isComplete: Bool { earned >= perDay }
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
  /// Tracks credited per day key — the server's once-per-track-per-day rule.
  private var listensByDay: [String: Set<String>] = [:]

  /// Failure switches — the next matching call throws.
  var failsGarden = false
  var failsSelectPlant = false
  var failsSpend = false
  /// Whether the server judges tonight's attendance complete.
  var pauseEligible = true
  /// How many pause claims fail before one lands — exercises the claim's
  /// retry. Each failure throws `pauseClaimError`.
  var pauseClaimFailures = 0
  var pauseClaimError = APIError.transport("offline")
  /// How long each pause claim takes to answer — a slow network at 20:42.
  var pauseClaimDelay: Duration = .zero
  /// Every pause claim attempted, failed ones included.
  private(set) var pauseClaimAttempts = 0

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

  /// Mirrors the server's listen rules: one heart per track per day, at most
  /// `RewardRules.trackDailyLimit` a day, listens older than 48h left
  /// unjudged, and a finish stamped ahead of now (a fast clock) counted today.
  func reportListen(trackId: String, completedAt: Date) async throws -> ListenOutcome {
    let now = Date()
    guard now.timeIntervalSince(completedAt) <= 48 * 60 * 60 else {
      return ListenOutcome(judged: false, granted: false, tally: nil, grant: nil)
    }
    // ISO 8601 is always Gregorian, so the key reads the same on a Thai device.
    let dayKey = min(completedAt, now).formatted(
      Date.ISO8601FormatStyle(timeZone: .current).year().month().day()
    )
    let perDay = RewardRules.trackDailyLimit
    var earned = listensByDay[dayKey, default: []]
    let cappedBy: String?
    var grant: AwardGrant?
    if earned.contains(trackId) {
      cappedBy = "duplicate"
    } else if earned.count >= perDay {
      cappedBy = "kind_cap"
    } else if let granted = self.grant(hearts: 1, sunlight: 1) {
      earned.insert(trackId)
      listensByDay[dayKey] = earned
      cappedBy = nil
      grant = granted
    } else {
      cappedBy = "daily_cap"
    }
    return ListenOutcome(
      judged: true,
      granted: cappedBy == nil,
      cappedBy: cappedBy,
      tally: ListenTally(dayKey: dayKey, earned: earned.count, perDay: perDay),
      grant: grant
    )
  }

  func claimPauseAward() async throws -> PauseAwardClaim {
    pauseClaimAttempts += 1
    if pauseClaimDelay > .zero {
      try await Task.sleep(for: pauseClaimDelay)
    }
    if pauseClaimFailures > 0 {
      pauseClaimFailures -= 1
      throw pauseClaimError
    }
    guard pauseEligible else { return PauseAwardClaim(eligible: false, grant: nil) }
    guard !pauseAwardClaimed else { return PauseAwardClaim(eligible: true, grant: nil) }
    pauseAwardClaimed = true
    return PauseAwardClaim(eligible: true, grant: grant(hearts: 5, sunlight: 5))
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

  func reportListen(trackId: String, completedAt: Date) async throws -> ListenOutcome {
    let dto: ListenResponseDTO = try await client.request(
      "/me/sound/listens",
      method: "POST",
      body: ListenRequestDTO(
        trackId: trackId,
        completedAt: Self.isoFormatter.string(from: completedAt)
      )
    )
    return ListenOutcome(
      judged: dto.award != nil,
      granted: dto.award?.granted == true,
      cappedBy: dto.award?.cappedBy,
      tally: dto.listens.map {
        ListenTally(dayKey: $0.dayKey, earned: $0.earned, perDay: $0.perDay)
      },
      grant: AwardGrant(outcomes: [dto.award].compactMap { $0 }, wallet: dto.wallet, plant: dto.plant)
    )
  }

  /// UTC with fractional seconds ("2026-10-09T12:34:56.789Z") — what the
  /// server's `datetime({ offset: true })` accepts, matching the practice sync.
  private static let isoFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  func claimPauseAward() async throws -> PauseAwardClaim {
    let dto: PauseAwardResponseDTO = try await client.request(
      "/me/pause/award",
      method: "POST"
    )
    return PauseAwardClaim(
      eligible: dto.eligible ?? true,
      grant: AwardGrant(outcomes: [dto.award].compactMap { $0 }, wallet: dto.wallet, plant: dto.plant)
    )
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
