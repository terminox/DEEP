import Foundation

/// The reward state one finished practice hands to its ending ritual — a DEEP
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
  /// Whether the continuity figures can be trusted — false when the practice
  /// journal had never been hydrated from the server by the time the ending
  /// was composed (a fresh install, a just-signed-in account offline). The
  /// beat then rests rather than show a number that may be wrong.
  var continuityKnown: Bool = true
  /// True when a Global Pause night earned no attendance hearts because the
  /// member wasn't present through the meditation — the ending says so rather
  /// than calling the day full.
  var attendanceMissed: Bool = false
  /// True when a Global Pause night's attendance claim had no answer yet when
  /// the ending was composed. Whether hearts are coming is unknown, so the
  /// ending neither promises them nor calls the day full.
  var attendancePending: Bool = false

  /// The rhythm is noticed once a day, and only when there is a rhythm to
  /// notice: a member with no returning days behind them meets the beat on the
  /// day it first means something.
  var showsContinuity: Bool {
    continuityKnown && !continuityWitnessedToday && continuityAfter > 0
  }

  /// Whether the ending should explain the missing hearts: nothing came, and
  /// the reason is the night's attendance rather than the day's ceiling.
  var explainsMissedAttendance: Bool {
    attendanceMissed && heartsAwarded == 0
  }

  /// Whether the night's award is still on its way with nothing else in hand:
  /// the reward lines rest (no "+N", no "Today is full") and the cards keep
  /// only the figures already true.
  var awaitsAttendanceAward: Bool {
    attendancePending && rewardsAreFull
  }

  /// Whether today's practice is what extended the rhythm — the beat names it
  /// a return ("You returned today") rather than a continuation.
  var returnedToday: Bool {
    continuityAfter > continuityBefore
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
  /// message, arriving together, on a day an earlier practice already kept —
  /// the rhythm continues rather than moves.
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

  /// The day's first practice is tonight's pause: the run grows by one.
  static let pauseReturn = RewardReceipt(
    gardenBefore: GardenGrowth(plant: .oakFixture, sunlight: 240),
    gardenAfter: GardenGrowth(plant: .oakFixture, sunlight: 245),
    sunlightAwarded: 5,
    heartBalanceBefore: 12,
    heartBalanceAfter: 17,
    heartsEarnedTodayBefore: 0,
    heartsEarnedTodayAfter: 5,
    heartsAwarded: 5,
    continuityBefore: 7,
    continuityAfter: 8,
    continuityWitnessedToday: false
  )

  /// A night the pause award could not be claimed — already claimed, or the
  /// day's ceiling reached. Nothing is promised and nothing moves.
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

  /// A night the member left the meditation early (or joined it late): the
  /// server didn't count the attendance, and the ending says why.
  static let pauseMissed = RewardReceipt(
    gardenBefore: GardenGrowth(plant: .oakFixture, sunlight: 246),
    gardenAfter: GardenGrowth(plant: .oakFixture, sunlight: 246),
    sunlightAwarded: 0,
    heartBalanceBefore: 18,
    heartBalanceAfter: 18,
    heartsEarnedTodayBefore: 3,
    heartsEarnedTodayAfter: 3,
    heartsAwarded: 0,
    continuityBefore: 7,
    continuityAfter: 7,
    continuityWitnessedToday: true,
    attendanceMissed: true
  )

  /// A night whose attendance claim hadn't answered when the ending composed:
  /// no hearts promised, no full day claimed, and the rhythm beat resting.
  static let pausePending = RewardReceipt(
    gardenBefore: GardenGrowth(plant: .oakFixture, sunlight: 240),
    gardenAfter: GardenGrowth(plant: .oakFixture, sunlight: 240),
    sunlightAwarded: 0,
    heartBalanceBefore: 12,
    heartBalanceAfter: 12,
    heartsEarnedTodayBefore: 2,
    heartsEarnedTodayAfter: 2,
    heartsAwarded: 0,
    continuityBefore: 7,
    continuityAfter: 7,
    continuityWitnessedToday: false,
    continuityKnown: false,
    attendancePending: true
  )
}
