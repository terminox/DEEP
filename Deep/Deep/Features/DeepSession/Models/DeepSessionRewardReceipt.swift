import Foundation

/// The reward state one finished Deep Session hands to its ending ritual.
///
/// Both sides of every change are captured before the first reward screen is
/// shown. Server reconciliation may continue behind the ritual, but it cannot
/// jump a number or replay an animation the member is already watching.
struct DeepSessionRewardReceipt: Equatable {
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
  let completionsTodayBefore: Int
  /// Continuity is witnessed once: when this session is the first completion
  /// recorded on the device's current calendar day.
  var showsContinuity: Bool {
    completionsTodayBefore == 0
  }

  var gardenIsCatchingUp: Bool {
    gardenAfter == nil
  }

  var rewardsAreFull: Bool {
    sunlightAwarded == 0 && heartsAwarded == 0
  }
}

extension DeepSessionRewardReceipt {
  static let sample = DeepSessionRewardReceipt(
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
    completionsTodayBefore: 0
  )

  static let laterToday = DeepSessionRewardReceipt(
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
    completionsTodayBefore: 1
  )

  static let capped = DeepSessionRewardReceipt(
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
    completionsTodayBefore: 4
  )

  static let evolving = DeepSessionRewardReceipt(
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
    completionsTodayBefore: 0
  )

  static let catchingUp = DeepSessionRewardReceipt(
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
    completionsTodayBefore: 0
  )
}
