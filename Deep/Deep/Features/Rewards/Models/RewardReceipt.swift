import Foundation

/// The reward state one finished practice hands to its ending ritual — a Deep
/// Session, a Global Pause, anything that closes on the reward beats.
///
/// Both sides of every change are captured before the first reward screen is
/// shown. Server reconciliation may continue behind the ritual, but it cannot
/// jump a number or replay an animation the member is already watching.
struct RewardReceipt: Equatable {
  let gardenBefore: GardenGrowth?
  let gardenAfter: GardenGrowth?
  let sunlightAwarded: Int

  let heartBalanceBefore: Int
  let heartBalanceAfter: Int
  let heartsEarnedTodayBefore: Int
  let heartsEarnedTodayAfter: Int
  let heartsAwarded: Int

  let continuityBefore: Int
  let continuityAfter: Int
  /// Whether an earlier practice today already witnessed the rhythm — the one
  /// day-stamp `ContinuityWitness` keeps for every feature.
  let continuityWitnessedToday: Bool

  /// The rhythm is noticed once a day, and only when there is a rhythm to
  /// notice: a member with no returning days behind them meets the beat on the
  /// day it first means something.
  var showsContinuity: Bool {
    !continuityWitnessedToday && continuityAfter > 0
  }

  var gardenIsCatchingUp: Bool {
    gardenAfter == nil
  }

  var rewardsAreFull: Bool {
    sunlightAwarded == 0 && heartsAwarded == 0
  }
}

extension RewardReceipt {
  static let sample = RewardReceipt(
    gardenBefore: GardenGrowth(plant: .oakFixture, sunlight: 240),
    gardenAfter: GardenGrowth(plant: .oakFixture, sunlight: 241),
    sunlightAwarded: 1,
    heartBalanceBefore: 12,
    heartBalanceAfter: 13,
    heartsEarnedTodayBefore: 2,
    heartsEarnedTodayAfter: 3,
    heartsAwarded: 1,
    continuityBefore: 6,
    continuityAfter: 7,
    continuityWitnessedToday: false
  )

  static let laterToday = RewardReceipt(
    gardenBefore: GardenGrowth(plant: .sakuraFixture, sunlight: 90),
    gardenAfter: GardenGrowth(plant: .sakuraFixture, sunlight: 91),
    sunlightAwarded: 1,
    heartBalanceBefore: 4,
    heartBalanceAfter: 5,
    heartsEarnedTodayBefore: 1,
    heartsEarnedTodayAfter: 2,
    heartsAwarded: 1,
    continuityBefore: 7,
    continuityAfter: 7,
    continuityWitnessedToday: true
  )

  static let capped = RewardReceipt(
    gardenBefore: GardenGrowth(plant: .oakFixture, sunlight: 240),
    gardenAfter: GardenGrowth(plant: .oakFixture, sunlight: 240),
    sunlightAwarded: 0,
    heartBalanceBefore: 18,
    heartBalanceAfter: 18,
    heartsEarnedTodayBefore: 4,
    heartsEarnedTodayAfter: 4,
    heartsAwarded: 0,
    continuityBefore: 12,
    continuityAfter: 12,
    continuityWitnessedToday: true
  )

  static let evolving = RewardReceipt(
    gardenBefore: GardenGrowth(plant: .oakFixture, sunlight: 199),
    gardenAfter: GardenGrowth(plant: .oakFixture, sunlight: 200),
    sunlightAwarded: 1,
    heartBalanceBefore: 2,
    heartBalanceAfter: 3,
    heartsEarnedTodayBefore: 0,
    heartsEarnedTodayAfter: 1,
    heartsAwarded: 1,
    continuityBefore: 0,
    continuityAfter: 1,
    continuityWitnessedToday: false
  )

  static let catchingUp = RewardReceipt(
    gardenBefore: nil,
    gardenAfter: nil,
    sunlightAwarded: 0,
    heartBalanceBefore: 2,
    heartBalanceAfter: 3,
    heartsEarnedTodayBefore: 0,
    heartsEarnedTodayAfter: 1,
    heartsAwarded: 1,
    continuityBefore: 0,
    continuityAfter: 1,
    continuityWitnessedToday: false
  )

  /// A whole Global Pause night: the attendance award and a first peace
  /// message, arriving together. The rhythm is witnessed, not incremented — a
  /// pause night adds no practice day.
  static let pauseNight = RewardReceipt(
    gardenBefore: GardenGrowth(plant: .oakFixture, sunlight: 240),
    gardenAfter: GardenGrowth(plant: .oakFixture, sunlight: 246),
    sunlightAwarded: 6,
    heartBalanceBefore: 12,
    heartBalanceAfter: 18,
    heartsEarnedTodayBefore: 2,
    heartsEarnedTodayAfter: 8,
    heartsAwarded: 6,
    continuityBefore: 7,
    continuityAfter: 7,
    continuityWitnessedToday: false
  )

  /// A night the pause award could not be claimed — left early, or already
  /// claimed. Nothing is promised and nothing moves.
  static let pauseRested = RewardReceipt(
    gardenBefore: GardenGrowth(plant: .oakFixture, sunlight: 246),
    gardenAfter: GardenGrowth(plant: .oakFixture, sunlight: 246),
    sunlightAwarded: 0,
    heartBalanceBefore: 18,
    heartBalanceAfter: 18,
    heartsEarnedTodayBefore: 8,
    heartsEarnedTodayAfter: 8,
    heartsAwarded: 0,
    continuityBefore: 7,
    continuityAfter: 7,
    continuityWitnessedToday: true
  )
}
