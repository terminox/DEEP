import SwiftUI
import Observation

/// The app's one answer to "does this person have DEEP Premium?".
///
/// `SubscriptionStore` stays purely about purchasing; this is where its answer
/// meets the server's. Every lock decision reads `hasPremium` and hands it to
/// `PremiumGate` — no screen asks the store directly.
///
/// The server side is stubbed to unknown for now, so `hasPremium` is exactly
/// the store's answer, as it was before this type existed.
@MainActor
@Observable
final class PremiumAccess {
  /// The purchasing side. Observable through the existential, so a view
  /// reading `hasPremium` re-renders when the store's status moves.
  @ObservationIgnored let store: any SubscriptionStore

  init(store: any SubscriptionStore) {
    self.store = store
  }

  /// What the server last said; `nil` until it has been asked.
  var server: Bool? { nil }

  var hasPremium: Bool { store.isSubscribed }
}

extension EnvironmentValues {
  /// The shared premium answer. `AppRootView` injects the real one, and the
  /// UIKit tab shell re-injects it per tab, since the SwiftUI environment does
  /// not survive that boundary. The default rides the hermetic preview store,
  /// which reads as "not subscribed".
  @Entry var premiumAccess: PremiumAccess = PremiumAccess(store: PreviewSubscriptionStore())
}

#if DEBUG
extension PremiumAccess {
  /// A member, for previews — every lock open.
  static var member: PremiumAccess { PremiumAccess(store: MockSubscriptionStore.subscribed) }
  /// Someone on the free plan, for previews — premium content locked.
  static var free: PremiumAccess { PremiumAccess(store: MockSubscriptionStore.free) }
}
#endif
