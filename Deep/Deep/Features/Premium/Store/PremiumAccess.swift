import SwiftUI
import Observation

/// The app's one answer to "does this person have DEEP Premium?".
///
/// `SubscriptionStore` stays purely about purchasing; this is where its answer
/// meets the server's. Every lock decision reads `hasPremium` and hands it to
/// `PremiumGate` — no screen asks the store directly.
///
/// **The rule is the union.** Premium is granted when the server says so, *or*
/// the store says so, *or* a purchase has just completed and the server hasn't
/// caught up yet. The costs are asymmetric: a false lock on a member whose
/// webhook hasn't landed is a refund request, while a false unlock costs at
/// most a tap — the server still withholds the audio itself.
///
/// The server's last answer is remembered per member, so a launch where the
/// store is still checking — or the server is unreachable — opens on what the
/// server last said rather than regressing to locked.
@MainActor
@Observable
final class PremiumAccess {
  /// How long a completed purchase unlocks on its own word, while the server
  /// hears about it.
  nonisolated static let graceWindow: TimeInterval = 120

  /// The waits between asking the server again after a purchase — the
  /// onboarding config's retry ladder, stretched to span the grace window.
  nonisolated static let confirmationDelays: [Duration] = [
    .seconds(1), .seconds(2), .seconds(4), .seconds(8), .seconds(15), .seconds(30), .seconds(60),
  ]

  /// The purchasing side. Observed (see `observeStore()`), not owned.
  @ObservationIgnored let store: any SubscriptionStore
  @ObservationIgnored private let fetcher: (any EntitlementFetching)?
  @ObservationIgnored private let cache: ServerAnswerCache
  @ObservationIgnored private let now: () -> Date
  @ObservationIgnored private let sleep: (Duration) async throws -> Void
  @ObservationIgnored private let confirmationDelays: [Duration]
  @ObservationIgnored private var confirmationTask: Task<Void, Never>?
  @ObservationIgnored private var graceTask: Task<Void, Never>?
  /// Whether the server has answered since launch — a remembered answer is a
  /// stand-in, not an answer.
  @ObservationIgnored private(set) var hasServerAnswerThisSession = false

  /// What the server last said for this member: `nil` until it has ever
  /// answered (or after sign-out), remembered across launches otherwise.
  private(set) var server: Bool?
  /// The server's full answer, when one arrived this session.
  private(set) var entitlement: ServerEntitlement?
  /// Until when a completed purchase unlocks on its own word.
  private(set) var graceUntil: Date?
  /// The answer every lock reads.
  private(set) var hasPremium: Bool
  /// Moves exactly once each time `hasPremium` flips.
  private(set) var flipCount = 0
  /// Moves whenever content fetched earlier may carry stale verdicts: on every
  /// flip of `hasPremium`, *and* whenever the server changes its own answer.
  /// The second matters right after a purchase — `hasPremium` turned true on
  /// the store's word and stays true when the server catches up, but the audio
  /// the server withheld until then only arrives with a re-fetch. Content
  /// screens key their loading on this: `.task(id: premiumAccess.contentEpoch)`.
  private(set) var contentEpoch = 0

  init(
    store: any SubscriptionStore,
    fetcher: (any EntitlementFetching)? = nil,
    defaults: UserDefaults = .standard,
    now: @escaping () -> Date = Date.init,
    sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
    confirmationDelays: [Duration] = PremiumAccess.confirmationDelays
  ) {
    let cache = ServerAnswerCache(defaults: defaults)
    self.store = store
    self.fetcher = fetcher
    self.cache = cache
    self.now = now
    self.sleep = sleep
    self.confirmationDelays = confirmationDelays
    let remembered = cache.load()?.active
    self.server = remembered
    self.hasPremium = Self.resolve(server: remembered, store: store.status, insideGrace: false)
    observeStore()
  }

  /// The reconciliation truth table. `store` being `.unknown` — RevenueCat
  /// still checking — counts for nothing on its own; the server's remembered
  /// answer carries the launch until the store settles.
  nonisolated static func resolve(server: Bool?, store: SubscriptionState, insideGrace: Bool) -> Bool {
    if server == true || insideGrace { return true }
    if case .subscribed = store { return true }
    return false
  }

  private var insideGrace: Bool {
    graceUntil.map { now() < $0 } ?? false
  }

  // MARK: - The server's answer

  /// Asks the server. Any failure changes nothing: the last answer — the
  /// server's remembered one, or the store's cached one — stands.
  func refresh() async {
    guard let fetcher else { return }
    guard let answer = try? await fetcher.currentEntitlement() else { return }
    adopt(answer)
  }

  /// Asks the server only if it hasn't answered since launch — the launch
  /// session restore often carries the answer already.
  func refreshIfUnanswered() async {
    guard !hasServerAnswerThisSession else { return }
    await refresh()
  }

  /// Takes an answer the server sent, from wherever it arrived (`/me`, or the
  /// sign-in response). `nil` is an older server saying nothing, which
  /// changes nothing.
  func adopt(_ answer: ServerEntitlement?) {
    guard let answer else { return }
    let previous = server
    hasServerAnswerThisSession = true
    entitlement = answer
    server = answer.isActive
    cache.save(ServerAnswerCache.Entry(owner: cache.load()?.owner, active: answer.isActive))
    let flipped = reconcile()
    // The server changed its mind without `hasPremium` moving (it was already
    // carried by the store or a grace window): content still needs the audio
    // the server now releases, or no longer does.
    if !flipped, let previous, previous != answer.isActive {
      contentEpoch += 1
    }
  }

  /// Follows the signed-in member. A different member — or none — must never
  /// inherit the previous one's remembered answer.
  func identify(userID: String?) {
    guard let userID else {
      forgetServer()
      return
    }
    if let owner = cache.load()?.owner, owner != userID {
      forgetServer()
    }
    cache.save(ServerAnswerCache.Entry(owner: userID, active: server))
  }

  private func forgetServer() {
    confirmationTask?.cancel()
    confirmationTask = nil
    cache.clear()
    server = nil
    entitlement = nil
    graceUntil = nil
    hasServerAnswerThisSession = false
    reconcile()
  }

  // MARK: - After a purchase

  /// A purchase just completed: unlock now, on the store's word, and keep
  /// asking the server until it agrees or the ladder runs out. The server is
  /// first nudged to re-check with RevenueCat rather than wait for the
  /// webhook; that nudge failing (rate-limited, or not configured locally) is
  /// fine — the ladder still asks.
  func didPurchase() {
    graceUntil = now().addingTimeInterval(Self.graceWindow)
    reconcile()
    graceTask?.cancel()
    graceTask = Task { [weak self, sleep] in
      try? await sleep(.seconds(Self.graceWindow))
      self?.reconcile()
    }
    confirmationTask?.cancel()
    confirmationTask = Task { [weak self] in await self?.confirmPurchase() }
  }

  /// The confirmation ladder, awaitable so tests can run it to the end.
  func confirmPurchase() async {
    guard let fetcher else { return }
    if let nudged = try? await fetcher.refreshEntitlement() { adopt(nudged) }
    for delay in confirmationDelays {
      if server == true || Task.isCancelled { return }
      guard (try? await sleep(delay)) != nil else { return }
      if let answer = try? await fetcher.currentEntitlement() { adopt(answer) }
    }
  }

  // MARK: - Reconciling

  /// Recomputes the answer, counting a flip only when it actually flips.
  /// Returns whether it did.
  @discardableResult
  func reconcile() -> Bool {
    let next = Self.resolve(server: server, store: store.status, insideGrace: insideGrace)
    guard next != hasPremium else { return false }
    hasPremium = next
    flipCount += 1
    contentEpoch += 1
    return true
  }

  /// Re-arming observation of the store's status (the `observeHasTrack`
  /// pattern), so a renewal, refund or expiry reaches `hasPremium` without
  /// anyone calling in. `onChange` fires at willSet; the hop reads the new
  /// value.
  private func observeStore() {
    _ = withObservationTracking {
      store.status
    } onChange: { [weak self] in
      Task { @MainActor [weak self] in
        self?.reconcile()
        self?.observeStore()
      }
    }
  }
}

/// The server's last answer, remembered across launches with the member it
/// was about. Stored apart from the store's own cache: they are two different
/// witnesses, and neither may overwrite the other.
struct ServerAnswerCache {
  private static let key = "deep.premium.server"

  struct Entry: Codable, Equatable {
    /// The DEEP user id the answer belongs to, once known.
    var owner: String?
    /// The server's answer; `nil` while the owner is known but unanswered.
    var active: Bool?
  }

  private let defaults: UserDefaults

  init(defaults: UserDefaults) {
    self.defaults = defaults
  }

  func load() -> Entry? {
    guard let data = defaults.data(forKey: Self.key) else { return nil }
    return try? JSONDecoder().decode(Entry.self, from: data)
  }

  func save(_ entry: Entry) {
    guard let data = try? JSONEncoder().encode(entry) else { return }
    defaults.set(data, forKey: Self.key)
  }

  func clear() {
    defaults.removeObject(forKey: Self.key)
  }
}

extension EnvironmentValues {
  /// The shared premium answer. `AppRootView` injects the real one, and the
  /// UIKit tab shell re-injects it per tab, since the SwiftUI environment does
  /// not survive that boundary. The default rides the hermetic preview store,
  /// which reads as "not subscribed".
  @Entry var premiumAccess: PremiumAccess = PremiumAccess(
    store: PreviewSubscriptionStore(),
    defaults: UserDefaults(suiteName: "deep.premium.preview") ?? .standard
  )
}

#if DEBUG
extension PremiumAccess {
  /// A member, for previews — every lock open.
  static var member: PremiumAccess {
    PremiumAccess(store: MockSubscriptionStore.subscribed, defaults: previewDefaults)
  }

  /// Someone on the free plan, for previews — premium content locked.
  static var free: PremiumAccess {
    PremiumAccess(store: MockSubscriptionStore.free, defaults: previewDefaults)
  }

  /// A throwaway suite, so a preview never reads or writes the real answer.
  private static var previewDefaults: UserDefaults {
    UserDefaults(suiteName: "deep.premium.preview") ?? .standard
  }
}
#endif
