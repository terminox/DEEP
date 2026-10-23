import Foundation

/// The books as they stood the moment the meditation ended — frozen before the
/// attendance claim goes out, so the ending ritual can show a true before/after
/// even though the grants land asynchronously behind the reflection.
///
/// Global Pause awards are server-settled (5 hearts and 5 sunlight for the
/// night, another pair for a first peace message), so unlike a DEEP Session
/// there is no optimistic credit to read back: the "before" has to be kept.
///
/// The rhythm is deliberately not frozen here: a counted pause keeps the day,
/// and whether it does is only known once the claim settles — so the ending
/// reads the journal's `continuityTransition()` when it composes the receipt.
struct GlobalPauseRewardSnapshot: Equatable {
  let garden: GardenGrowth?
  let heartBalance: Int
  let heartsEarnedToday: Int
  let continuityWitnessedToday: Bool
}

extension GlobalPauseRewardSnapshot {
  /// A mid-journey member arriving at tonight's ending.
  static let sample = GlobalPauseRewardSnapshot(
    garden: GardenGrowth(plant: .oakFixture, sunlight: 240),
    heartBalance: 12,
    heartsEarnedToday: 2,
    continuityWitnessedToday: false
  )

  /// A member whose DEEP Session already witnessed the rhythm today.
  static let rhythmWitnessed = GlobalPauseRewardSnapshot(
    garden: GardenGrowth(plant: .oakFixture, sunlight: 240),
    heartBalance: 12,
    heartsEarnedToday: 2,
    continuityWitnessedToday: true
  )
}

extension RewardReceipt {
  /// Folds a pause night's settled grants onto the snapshot the ending froze.
  /// The shared award sink has already handed both grants to the ledger and the
  /// garden, so the "after" side is simply what those stores now hold — the
  /// grants are only read for what this night actually gave.
  ///
  /// The rhythm comes from the journal as the ending composes: a counted pause
  /// that is the day's first practice moves it on by one, anything else leaves
  /// it where it stands. While the claim is still unanswered the journal can't
  /// know yet whether tonight keeps the day, so the beat rests (unknown) rather
  /// than show a rhythm that may be about to move.
  init(
    pauseNight before: GlobalPauseRewardSnapshot,
    awards: [AwardGrant],
    gardenAfter: GardenGrowth?,
    heartBalanceAfter: Int,
    heartsEarnedTodayAfter: Int,
    continuity: ContinuityTransition,
    continuityKnown: Bool,
    attendanceMissed: Bool,
    attendancePending: Bool = false
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
      continuityBefore: continuity.before,
      continuityAfter: continuity.after,
      continuityWitnessedToday: before.continuityWitnessedToday,
      continuityKnown: continuityKnown && !attendancePending,
      attendanceMissed: attendanceMissed,
      attendancePending: attendancePending
    )
  }
}
