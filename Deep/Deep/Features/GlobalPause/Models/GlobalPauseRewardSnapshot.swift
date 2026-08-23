import Foundation

/// The books as they stood the moment the meditation ended — frozen before the
/// attendance claim goes out, so the ending ritual can show a true before/after
/// even though the grants land asynchronously behind the reflection.
///
/// Global Pause awards are server-settled (5 hearts and 5 sunlight for the
/// night, another pair for a first peace message), so unlike a Deep Session
/// there is no optimistic credit to read back: the "before" has to be kept.
struct GlobalPauseRewardSnapshot: Equatable {
  let garden: GardenGrowth?
  let heartBalance: Int
  let heartsEarnedToday: Int
  /// Days of returning as the practice journal has them. A pause night adds no
  /// practice day, so this number is witnessed by the ritual, never moved.
  let continuityDays: Int
  let continuityWitnessedToday: Bool
}

extension GlobalPauseRewardSnapshot {
  /// A mid-journey member arriving at tonight's ending.
  static let sample = GlobalPauseRewardSnapshot(
    garden: GardenGrowth(plant: .oakFixture, sunlight: 240),
    heartBalance: 12,
    heartsEarnedToday: 2,
    continuityDays: 7,
    continuityWitnessedToday: false
  )

  /// A member whose Deep Session already witnessed the rhythm today.
  static let rhythmWitnessed = GlobalPauseRewardSnapshot(
    garden: GardenGrowth(plant: .oakFixture, sunlight: 240),
    heartBalance: 12,
    heartsEarnedToday: 2,
    continuityDays: 7,
    continuityWitnessedToday: true
  )
}

extension RewardReceipt {
  /// Folds a pause night's settled grants onto the snapshot the ending froze.
  /// The shared award sink has already handed both grants to the ledger and the
  /// garden, so the "after" side is simply what those stores now hold — the
  /// grants are only read for what this night actually gave.
  ///
  /// Continuity is witnessed, not moved: a pause night adds no practice day.
  init(
    pauseNight before: GlobalPauseRewardSnapshot,
    awards: [AwardGrant],
    gardenAfter: GardenGrowth?,
    heartBalanceAfter: Int,
    heartsEarnedTodayAfter: Int
  ) {
    self.init(
      gardenBefore: before.garden,
      gardenAfter: gardenAfter,
      sunlightAwarded: awards.reduce(0) { $0 + $1.sunlight },
      heartBalanceBefore: before.heartBalance,
      heartBalanceAfter: heartBalanceAfter,
      heartsEarnedTodayBefore: before.heartsEarnedToday,
      heartsEarnedTodayAfter: heartsEarnedTodayAfter,
      heartsAwarded: awards.reduce(0) { $0 + $1.hearts },
      continuityBefore: before.continuityDays,
      continuityAfter: before.continuityDays,
      continuityWitnessedToday: before.continuityWitnessedToday
    )
  }
}
