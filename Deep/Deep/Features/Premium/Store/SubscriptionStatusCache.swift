import Foundation

/// The last-known entitlement, remembered across launches so the paywall and
/// the Settings plan chip open on the right state immediately, rather than on
/// "Checking…" while the store is queried.
///
/// It lives apart from any one store conformer because two of them must never
/// encode this key differently — a StoreKit build and a RevenueCat build have
/// to read each other's cache across an app update.
struct SubscriptionStatusCache {
  private static let key = "deep.subscription.status"
  private static let subscribedPrefix = "subscribed:"

  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  /// The remembered entitlement, or `nil` when nothing has been cached yet.
  func load() -> SubscriptionState? {
    guard let raw = defaults.string(forKey: Self.key) else { return nil }
    // `SubscriptionState.none` is spelled out on purpose: inside a function
    // returning an optional, a bare `.none` is `Optional.none` — nil — and a
    // remembered "free plan" would silently read as "nothing remembered",
    // leaving every launch on `.unknown`.
    if raw == "none" { return SubscriptionState.none }
    if raw.hasPrefix(Self.subscribedPrefix) {
      return .subscribed(productID: String(raw.dropFirst(Self.subscribedPrefix.count)))
    }
    return nil
  }

  func save(_ state: SubscriptionState) {
    let raw: String
    switch state {
    case .subscribed(let id): raw = Self.subscribedPrefix + id
    case .none: raw = "none"
    case .unknown: return // the transient state is not worth remembering
    }
    defaults.set(raw, forKey: Self.key)
  }
}
