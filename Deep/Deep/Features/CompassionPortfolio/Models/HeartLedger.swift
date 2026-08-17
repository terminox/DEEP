import SwiftUI

/// The user's living compassion portfolio: how many hearts they hold, where the
/// community's hearts have gone, and the outcomes reported back from the field.
///
/// A reference type so a single source of truth is shared across the coordinator
/// and every leaf screen (home, category detail, project cards) — sending a heart
/// from anywhere updates the balance and the cause's pooled total everywhere at
/// once. Injected through the environment, mirroring `\.soundPlayer`.
@Observable
final class HeartLedger {
  /// The most hearts one day of practice can hand you. A ceiling, not a target:
  /// the day fills up and then rests, so practice never turns into farming.
  static let dailyEarnCeiling = 30

  /// Hearts the user currently holds, earned through practice in the app.
  private(set) var balance: Int
  /// Hearts the user has personally given so far.
  private(set) var heartsGiven: Int
  private(set) var categories: [CompassionCategory]
  let reports: [FieldReport]

  init(
    balance: Int,
    heartsGiven: Int = 0,
    heartsEarnedToday: Int = 0,
    givenByUser: [String: Int] = [:],
    categories: [CompassionCategory] = CompassionLibrary.categories,
    reports: [FieldReport] = CompassionLibrary.reports
  ) {
    self.balance = balance
    self.heartsGiven = heartsGiven
    self.earnedTally = min(heartsEarnedToday, Self.dailyEarnCeiling)
    self.tallyDay = .now
    self.givenByUser = givenByUser
    self.categories = categories
    self.reports = reports
  }

  /// Whether the user has a heart left to give.
  var canGive: Bool { balance > 0 }

  // MARK: - Today

  /// Hearts credited so far today. Derived from the tally's date rather than
  /// stored, so a session left open past midnight reads zero on its own — no
  /// timer, and the same client-owned day maths `PracticeMath.minutesToday` uses.
  var heartsEarnedToday: Int {
    Calendar.current.isDateInToday(tallyDay) ? earnedTally : 0
  }

  /// Hearts today can still hand over.
  var heartsRemainingToday: Int {
    max(0, Self.dailyEarnCeiling - heartsEarnedToday)
  }

  /// Whether today has given everything it has.
  var isTodayFull: Bool { heartsRemainingToday == 0 }

  /// Distinct causes the user has contributed to.
  var causesSupported: Int {
    categories.filter { givenByUser[$0.id, default: 0] > 0 }.count
  }

  /// People reached across every cause. A *community* figure — the reach of
  /// every cause the app supports, not anything attributable to one user.
  var peopleReached: Int {
    categories.reduce(0) { $0 + $1.peopleReached }
  }

  /// Hearts the whole community has pooled across every cause — the total the
  /// allocation ring divides up.
  var heartsPooled: Int {
    categories.reduce(0) { $0 + $1.heartsShared }
  }

  /// Per-cause tally of hearts this user has personally sent, by category id.
  private var givenByUser: [String: Int]

  /// Hearts credited on `tallyDay`. Read through `heartsEarnedToday`, which
  /// discards it once the day has turned.
  private var earnedTally: Int
  /// The day `earnedTally` belongs to.
  private var tallyDay: Date

  /// Hearts *this user* has sent to one cause — the honest personal figure the
  /// cause detail closes on.
  func heartsGiven(in categoryID: String) -> Int {
    givenByUser[categoryID, default: 0]
  }

  /// The latest snapshot of a category (totals shift as hearts are sent).
  func category(_ id: String) -> CompassionCategory? {
    categories.first { $0.id == id }
  }

  /// Credits hearts earned through practice — a completed Deep Session calls
  /// this. Only what's left of today's ceiling is credited, so the figure the
  /// portfolio card shows is the whole truth; once the day is full this is a
  /// no-op. Animated so the balance settles softly wherever it's shown.
  ///
  /// Returns the hearts actually credited, so a caller can tell the user what
  /// happened rather than promising a heart the day can't give.
  @discardableResult
  func earn(_ hearts: Int = 1) -> Int {
    if !Calendar.current.isDateInToday(tallyDay) {
      tallyDay = .now
      earnedTally = 0
    }

    let credited = min(hearts, heartsRemainingToday)
    guard credited > 0 else { return 0 }

    withAnimation(.exhale) {
      balance += credited
      earnedTally += credited
    }
    return credited
  }

  /// Send a single heart to a cause — and, when given, the specific project the
  /// user tapped. No-op once the balance reaches zero. Animated so the balance
  /// and pooled totals settle together.
  func sendHeart(to category: CompassionCategory, project: CompassionProject? = nil) {
    guard canGive else { return }
    guard let index = categories.firstIndex(where: { $0.id == category.id }) else { return }

    withAnimation(.exhale) {
      balance -= 1
      heartsGiven += 1
      categories[index].heartsShared += 1
      givenByUser[category.id, default: 0] += 1

      if let project,
         let projectIndex = categories[index].projects.firstIndex(where: { $0.id == project.id }) {
        categories[index].projects[projectIndex].heartsShared += 1
      }
    }
  }
}

extension HeartLedger {
  /// A warm starting portfolio for previews and the running app. The per-cause
  /// spread sums to `heartsGiven`, so "causes supported" and each cause's "your
  /// part" line tell the same story as the headline figure. A day part-filled,
  /// which is the day strand's ordinary state.
  static var sample: HeartLedger {
    HeartLedger(
      balance: 2_450,
      heartsGiven: 318,
      heartsEarnedToday: 12,
      givenByUser: ["peace": 104, "healthcare": 96, "nature": 71, "education": 47]
    )
  }

  /// A first-run portfolio: hearts to give, nothing given yet, the day untouched.
  static var fresh: HeartLedger {
    HeartLedger(balance: 120, heartsGiven: 0)
  }

  /// An emptied portfolio for testing the "no hearts left" state — and, with a
  /// full day behind it, the one case where practice can't earn more until
  /// tomorrow.
  static var spent: HeartLedger {
    HeartLedger(
      balance: 0,
      heartsGiven: 980,
      heartsEarnedToday: dailyEarnCeiling,
      givenByUser: [
        "peace": 240, "healthcare": 228, "nature": 194, "education": 176, "community": 142,
      ]
    )
  }
}

extension EnvironmentValues {
  /// The shared compassion portfolio. The coordinator injects the live ledger;
  /// the default keeps previews hermetic.
  @Entry var heartLedger: HeartLedger = .sample
}
