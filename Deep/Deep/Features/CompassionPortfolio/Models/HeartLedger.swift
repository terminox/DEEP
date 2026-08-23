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
  /// Mirrors the server's daily cap.
  static let dailyEarnCeiling = 30

  /// A spend the server refused after the optimistic decrement had already
  /// played — the rollback's quiet caption reads it.
  struct SpendFailure: Equatable {
    let amount: Int
    let categoryID: String
  }

  /// Hearts the user currently holds, earned through practice in the app.
  private(set) var balance: Int
  /// Hearts the user has personally given so far.
  private(set) var heartsGiven: Int
  private(set) var categories: [CompassionCategory]
  let reports: [FieldReport]

  /// Set when a spend was rolled back; cleared by the next send or explicitly.
  private(set) var spendFailure: SpendFailure?

  /// The backend seam for real spends. Nil for fixtures, whose sends stay
  /// purely local — exactly the old behaviour.
  @ObservationIgnored private let remote: (any RewardsRemote)?
  /// The most recent spend's round trip — tests await it to make the
  /// reconcile/rollback deterministic.
  @ObservationIgnored private(set) var pendingSpend: Task<Void, Never>?

  init(
    balance: Int,
    heartsGiven: Int = 0,
    heartsEarnedToday: Int = 0,
    givenByUser: [String: Int] = [:],
    categories: [CompassionCategory] = CompassionLibrary.categories,
    reports: [FieldReport] = CompassionLibrary.reports,
    remote: (any RewardsRemote)? = nil
  ) {
    self.balance = balance
    self.heartsGiven = heartsGiven
    self.earnedTally = min(heartsEarnedToday, Self.dailyEarnCeiling)
    self.tallyDay = .now
    self.givenByUser = givenByUser
    self.categories = categories
    self.reports = reports
    self.remote = remote
  }

  /// The live ledger: starts empty and is hydrated by the first garden/wallet
  /// fetch — no more 2,450-heart fixture on launch.
  convenience init(remote: any RewardsRemote) {
    self.init(balance: 0, remote: remote)
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
    categories.heartsPooled
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

  /// Sends `hearts` to a cause — and, when given, the specific project the user
  /// tapped. The amount is clamped to the balance, so an over-ask gives
  /// everything that's left rather than failing; a member who types past what
  /// they hold gets the generous reading of what they meant. Animated so the
  /// balance and pooled totals settle together.
  ///
  /// Optimistic: the local books move immediately, then the spend goes to the
  /// server under a client-generated idempotency UUID. Success reconciles the
  /// balance to the server's absolute figures; refusal (`insufficient_hearts`,
  /// or any failure) rolls the whole mutation back and leaves a quiet
  /// `spendFailure` for the caption. Without a remote (fixtures, previews) the
  /// send stays purely local.
  func send(_ hearts: Int, to category: CompassionCategory, project: CompassionProject? = nil) {
    let amount = Swift.min(hearts, balance)
    guard amount > 0 else { return }
    guard let index = categories.firstIndex(where: { $0.id == category.id }) else { return }

    let projectID = project?.id
    spendFailure = nil
    withAnimation(.exhale) {
      balance -= amount
      heartsGiven += amount
      categories[index].heartsShared += amount
      givenByUser[category.id, default: 0] += amount

      if let projectID,
         let projectIndex = categories[index].projects.firstIndex(where: { $0.id == projectID }) {
        categories[index].projects[projectIndex].heartsShared += amount
      }
    }

    guard let remote else { return }
    let spendID = UUID()
    let categoryID = category.id
    pendingSpend = Task { [weak self] in
      do {
        let summary = try await remote.spendHearts(
          id: spendID, amount: amount, category: categoryID, projectId: projectID
        )
        self?.reconcile(with: summary)
      } catch {
        self?.rollback(amount, category: categoryID, projectID: projectID)
      }
    }
  }

  /// Adopts the server's absolute wallet figures — the garden fetch feeds this
  /// through `GardenStore.heartsChanged`, and a settled spend reconciles here.
  func hydrate(_ summary: HeartsSummary) {
    withAnimation(.exhale) {
      balance = summary.balance
      heartsGiven = summary.given
      earnedTally = min(summary.earnedToday, Self.dailyEarnCeiling)
      tallyDay = .now
      // Server truth for the per-cause spread; local optimistic sends are
      // already reflected there once their POST has landed.
      if !summary.givenByCategory.isEmpty || givenByUser.isEmpty {
        givenByUser = summary.givenByCategory
      }
    }
  }

  /// Applies a settled award. Absolutes SET the balance and today's tally, so
  /// the completion beat's optimistic `earn()` is reconciled rather than
  /// double-counted; the delta path only serves responses without snapshots.
  func apply(_ grant: AwardGrant) {
    withAnimation(.exhale) {
      if let balanceNow = grant.heartsBalance {
        balance = balanceNow
      } else if grant.hearts > 0 {
        balance += grant.hearts
      }
      if let earnedToday = grant.heartsEarnedToday {
        earnedTally = min(earnedToday, Self.dailyEarnCeiling)
        tallyDay = .now
      } else if grant.hearts > 0 {
        if !Calendar.current.isDateInToday(tallyDay) {
          tallyDay = .now
          earnedTally = 0
        }
        earnedTally = min(earnedTally + grant.hearts, Self.dailyEarnCeiling)
      }
      if let given = grant.heartsGiven {
        heartsGiven = given
      }
    }
  }

  /// Clears the rollback caption once it has been seen.
  func clearSpendFailure() {
    spendFailure = nil
  }

  /// Forgets the signed-out account's wallet, so the next account never sees a
  /// previous user's balance while its first garden fetch is still in flight.
  /// In-memory only (the ledger persists nothing); the community categories
  /// stay — they are app content, not user state.
  func resetLocalState() {
    balance = 0
    heartsGiven = 0
    earnedTally = 0
    tallyDay = .now
    givenByUser = [:]
    spendFailure = nil
  }

  /// A settled spend: the balance and given totals adopt the server's
  /// absolutes (normally identical to the optimistic figures, so nothing
  /// visibly moves).
  private func reconcile(with summary: HeartsSummary) {
    withAnimation(.exhale) {
      balance = summary.balance
      heartsGiven = summary.given
      if !summary.givenByCategory.isEmpty {
        givenByUser = summary.givenByCategory
      }
    }
  }

  /// Reverses one optimistic send after the server refused it.
  private func rollback(_ amount: Int, category categoryID: String, projectID: String?) {
    guard let index = categories.firstIndex(where: { $0.id == categoryID }) else { return }
    withAnimation(.exhale) {
      balance += amount
      heartsGiven -= amount
      categories[index].heartsShared -= amount
      givenByUser[categoryID, default: 0] -= amount
      if let projectID,
         let projectIndex = categories[index].projects.firstIndex(where: { $0.id == projectID }) {
        categories[index].projects[projectIndex].heartsShared -= amount
      }
      spendFailure = SpendFailure(amount: amount, categoryID: categoryID)
    }
  }

  /// Send a single heart to a cause — the one-tap paths. No-op once the balance
  /// reaches zero.
  func sendHeart(to category: CompassionCategory, project: CompassionProject? = nil) {
    send(1, to: category, project: project)
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

  /// A portfolio whose last send the server refused and rolled back — the
  /// quiet caption under the send/donate CTAs.
  static var sendRefused: HeartLedger {
    let ledger = sample
    ledger.spendFailure = SpendFailure(amount: 1, categoryID: "nature")
    return ledger
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
