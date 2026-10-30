import Foundation

/// The server's answer about DEEP Premium, narrowed to plain values.
///
/// deep-api is the authority on access — it hears RevenueCat's webhooks and
/// withholds premium audio from anyone it doesn't count as a member — so its
/// answer is one of the two inputs `PremiumAccess` reconciles.
struct ServerEntitlement: Equatable {
  let isActive: Bool
  var productID: String? = nil
  var expiresAt: Date? = nil
  var willRenew = false
  /// NORMAL | TRIAL | INTRO …, as RevenueCat names it.
  var periodType: String? = nil
  var inGracePeriod = false
  /// APP_STORE | PLAY_STORE | PROMOTIONAL …, as RevenueCat names it.
  var store: String? = nil
}

extension ServerEntitlement {
  /// Every field past `active` is read with a default, so a server that sends
  /// less than today's shape still yields an answer.
  init(dto: EntitlementDTO) {
    self.init(
      isActive: dto.active,
      productID: dto.productId,
      expiresAt: dto.expiresAt.flatMap(Self.date(from:)),
      willRenew: dto.willRenew ?? false,
      periodType: dto.periodType,
      inGracePeriod: dto.inGracePeriod ?? false,
      store: dto.store
    )
  }

  private static func date(from string: String) -> Date? {
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return fractional.date(from: string) ?? ISO8601DateFormatter().date(from: string)
  }
}

/// Asks the server whether this member has DEEP Premium.
///
/// A seam of its own so the account store never learns premium exists, and so
/// `PremiumAccess` tests against `MockEntitlementFetcher` without a network.
/// Both calls answer `nil` when there is no answer to give — signed out, or an
/// older server that doesn't send the entitlement — and throw when the server
/// couldn't be reached.
protocol EntitlementFetching: AnyObject {
  /// The current answer, from `GET /me`.
  func currentEntitlement() async throws -> ServerEntitlement?
  /// Asks the server to re-check with RevenueCat now rather than wait for the
  /// webhook (`POST /me/entitlement/refresh`, rate-limited per member).
  func refreshEntitlement() async throws -> ServerEntitlement?
}

/// `EntitlementFetching` over the DEEP API.
@MainActor
final class APIEntitlementFetcher: EntitlementFetching {
  private let client: APIClient

  init(client: APIClient) {
    self.client = client
  }

  func currentEntitlement() async throws -> ServerEntitlement? {
    // Signed out, there is no one to ask about — and an unauthenticated `/me`
    // would only 401.
    guard client.isAuthenticated else { return nil }
    let me: MeResponseDTO = try await client.request("/me")
    return me.entitlement.map(ServerEntitlement.init(dto:))
  }

  func refreshEntitlement() async throws -> ServerEntitlement? {
    guard client.isAuthenticated else { return nil }
    let response: EntitlementResponseDTO = try await client.request(
      "/me/entitlement/refresh",
      method: "POST"
    )
    return ServerEntitlement(dto: response.entitlement)
  }
}

#if DEBUG
/// Scripted `EntitlementFetching` for tests and previews: each call answers
/// with the next scripted result, repeating the last once the script runs out.
@MainActor
final class MockEntitlementFetcher: EntitlementFetching {
  struct Unreachable: Error {}

  /// Answers for `currentEntitlement()`, in order. `.failure` throws.
  var answers: [Result<ServerEntitlement?, Unreachable>]
  /// What `refreshEntitlement()` returns. Defaults to failing, the way a
  /// local server without a RevenueCat secret answers (503 `not_configured`).
  var refreshAnswer: Result<ServerEntitlement?, Unreachable> = .failure(Unreachable())

  private(set) var currentCalls = 0
  private(set) var refreshCalls = 0

  init(answers: [Result<ServerEntitlement?, Unreachable>] = [.success(nil)]) {
    self.answers = answers
  }

  func currentEntitlement() async throws -> ServerEntitlement? {
    let answer = answers.indices.contains(currentCalls) ? answers[currentCalls] : answers.last
    currentCalls += 1
    return try (answer ?? .success(nil)).get()
  }

  func refreshEntitlement() async throws -> ServerEntitlement? {
    refreshCalls += 1
    return try refreshAnswer.get()
  }
}

extension ServerEntitlement {
  static let member = ServerEntitlement(isActive: true, productID: DeepProduct.yearly, willRenew: true, store: "APP_STORE")
  static let lapsed = ServerEntitlement(isActive: false)
}
#endif
