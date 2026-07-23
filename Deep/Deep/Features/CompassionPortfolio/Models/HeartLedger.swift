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
  /// Hearts the user currently holds, earned through practice in the app.
  private(set) var balance: Int
  /// Hearts the user has personally given so far.
  private(set) var heartsGiven: Int
  private(set) var categories: [CompassionCategory]
  let reports: [FieldReport]

  init(
    balance: Int,
    heartsGiven: Int = 0,
    categories: [CompassionCategory] = CompassionLibrary.categories,
    reports: [FieldReport] = CompassionLibrary.reports
  ) {
    self.balance = balance
    self.heartsGiven = heartsGiven
    self.categories = categories
    self.reports = reports
  }

  /// Whether the user has a heart left to give.
  var canGive: Bool { balance > 0 }

  /// Distinct causes the user has contributed to.
  var causesSupported: Int {
    categories.filter { givenByUser[$0.id, default: 0] > 0 }.count
  }

  /// People reached across every cause — the headline reach figure.
  var peopleReached: Int {
    categories.reduce(0) { $0 + $1.peopleReached }
  }

  /// Per-cause tally of hearts this user has personally sent, by category id.
  private var givenByUser: [String: Int] = [:]

  /// The latest snapshot of a category (totals shift as hearts are sent).
  func category(_ id: String) -> CompassionCategory? {
    categories.first { $0.id == id }
  }

  /// Credits hearts earned through practice — a completed Deep Session calls
  /// this. Animated so the balance settles softly wherever it's shown.
  func earn(_ hearts: Int = 1) {
    withAnimation(.exhale) {
      balance += hearts
    }
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
  /// A warm starting portfolio for previews and the running app.
  static var sample: HeartLedger {
    HeartLedger(balance: 2_450, heartsGiven: 318)
  }

  /// A first-run portfolio: hearts to give, nothing given yet.
  static var fresh: HeartLedger {
    HeartLedger(balance: 120, heartsGiven: 0)
  }

  /// An emptied portfolio for testing the "no hearts left" state.
  static var spent: HeartLedger {
    HeartLedger(balance: 0, heartsGiven: 980)
  }
}

extension EnvironmentValues {
  /// The shared compassion portfolio. The coordinator injects the live ledger;
  /// the default keeps previews hermetic.
  @Entry var heartLedger: HeartLedger = .sample
}
