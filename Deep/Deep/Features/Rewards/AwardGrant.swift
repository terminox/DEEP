import Foundation

/// Client mirrors of the server's award rules — only the ones the UI needs to
/// promise honestly before the server has answered. The server remains the
/// authority; these gates only stop the app promising what can never be granted.
enum RewardRules {
  /// How many Deep Sessions can earn per day. The completion beat's optimistic
  /// heart is gated on this so it never promises a fifth heart the practice
  /// sync will not deliver.
  static let deepSessionDailyLimit = 4
}

/// One settled award from the server, as every producer (practice sync, track
/// listens, the pause claim, peace messages) hands it to the shared ingest
/// closure. Carries both the granted *deltas* and the *absolute* post-award
/// figures: `HeartLedger.apply` and `GardenStore.apply` SET the absolutes when
/// present, so an optimistic credit is reconciled rather than double-counted.
struct AwardGrant: Equatable {
  // MARK: Deltas — what this award actually granted.

  var hearts: Int = 0
  var sunlight: Int = 0
  /// The plant the sunlight was credited to.
  var plantId: String? = nil
  /// True when the day's hard hearts cap withheld the award entirely.
  var heartsCapped: Bool = false

  // MARK: Absolutes — the server's post-award truth, when it sent one.

  var heartsBalance: Int? = nil
  var heartsEarned: Int? = nil
  var heartsGiven: Int? = nil
  var heartsEarnedToday: Int? = nil
  var heartsRemainingToday: Int? = nil
  /// The credited plant's lifetime sunlight after this award.
  var plantSunlight: Int? = nil
  var plantStageIndex: Int? = nil
}

/// The wallet as the server holds it — the absolute figures `HeartLedger`
/// hydrates from. Rides `GET /me/garden`, `GET /me/wallet` and every spend
/// response.
struct HeartsSummary: Equatable {
  var balance: Int
  var earned: Int
  var given: Int
  var earnedToday: Int
  var remainingToday: Int
  var dailyCap: Int
  /// Hearts this user has sent, by compassion category id.
  var givenByCategory: [String: Int]
}

extension HeartsSummary {
  /// Mirrors `HeartLedger.sample` so mock-backed flows and previews agree.
  static let sample = HeartsSummary(
    balance: 2_450,
    earned: 2_768,
    given: 318,
    earnedToday: 12,
    remainingToday: 18,
    dailyCap: 30,
    givenByCategory: ["peace": 104, "healthcare": 96, "nature": 71, "education": 47]
  )

  /// A first-run wallet: hearts to give, nothing given, the day untouched.
  static let fresh = HeartsSummary(
    balance: 120,
    earned: 120,
    given: 0,
    earnedToday: 0,
    remainingToday: 30,
    dailyCap: 30,
    givenByCategory: [:]
  )
}
