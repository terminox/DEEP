import Foundation
import Observation

/// `AccountStore` backed by the Deep backend. Auth calls go through `APIClient`,
/// which persists the rotating token pair in the Keychain; this store keeps only
/// the (non-secret) `Account` identity for the UI — mirrored into `UserDefaults`
/// so an offline launch can restore the signed-in shell without the network.
@MainActor
@Observable
final class APIAccountStore: AccountStore {
  private static let cachedAccountKey = "deep.account.cached"

  private(set) var account: Account?
  private(set) var isRestoring = false

  private let client: APIClient
  private let defaults: UserDefaults

  init(client: APIClient, defaults: UserDefaults = .standard) {
    self.client = client
    self.defaults = defaults
  }

  /// Called once at launch. If a token pair is present, confirm it with `/me`
  /// (refreshing transparently). Only the server *rejecting* the session signs
  /// the user out; an unreachable backend keeps the session and restores the
  /// cached identity, so a dead network never drops a signed-in user onto the
  /// welcome screen.
  func restore() async {
    guard client.isAuthenticated else { return }
    isRestoring = true
    defer { isRestoring = false }
    do {
      let me: MeResponseDTO = try await client.request("/me")
      adopt(Self.account(from: me.user))
    } catch {
      if APIClient.isAuthRejection(error) {
        client.tokens.clear()
        clearCachedAccount()
        account = nil
      } else {
        // Offline / backend blip: stay signed in on the cached identity (or a
        // quiet placeholder for installs that predate the cache); persisted
        // stores render, and the next refresh confirms with the server.
        account = cachedAccount()
          ?? Account(displayName: "Friend", email: nil, method: .email, appleUserID: nil)
      }
    }
  }

  func signUp(name: String, email: String, password: String) async throws {
    let resp: AuthResponseDTO = try await client.request(
      "/auth/signup",
      method: "POST",
      body: SignupRequestDTO(email: email, password: password, displayName: name),
      authorized: false
    )
    client.tokens.save(access: resp.accessToken, refresh: resp.refreshToken)
    adopt(Self.account(from: resp.user))
  }

  func logIn(email: String, password: String) async throws {
    let resp: AuthResponseDTO = try await client.request(
      "/auth/login",
      method: "POST",
      body: LoginRequestDTO(email: email, password: password),
      authorized: false
    )
    client.tokens.save(access: resp.accessToken, refresh: resp.refreshToken)
    adopt(Self.account(from: resp.user))
  }

  func logOut() async {
    _ = try? await client.request("/auth/logout", method: "POST", as: OKResponseDTO.self)
    client.tokens.clear()
    clearCachedAccount()
    account = nil
  }

  func deleteAccount() async throws {
    _ = try await client.request("/me", method: "DELETE", as: OKResponseDTO.self)
    client.tokens.clear()
    clearCachedAccount()
    account = nil
  }

  // MARK: - Cached identity

  private func adopt(_ fresh: Account) {
    account = fresh
    if let data = try? JSONEncoder().encode(fresh) {
      defaults.set(data, forKey: Self.cachedAccountKey)
    }
  }

  private func cachedAccount() -> Account? {
    guard let data = defaults.data(forKey: Self.cachedAccountKey) else { return nil }
    return try? JSONDecoder().decode(Account.self, from: data)
  }

  private func clearCachedAccount() {
    defaults.removeObject(forKey: Self.cachedAccountKey)
  }

  private static func account(from dto: UserDTO) -> Account {
    Account(displayName: dto.displayName, email: dto.email, method: .email, appleUserID: nil)
  }
}
