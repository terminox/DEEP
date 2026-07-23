import Foundation
import Observation

/// `AccountStore` backed by the Deep backend. Auth calls go through `APIClient`,
/// which persists the rotating token pair in the Keychain; this store keeps only
/// the (non-secret) `Account` identity for the UI.
@MainActor
@Observable
final class APIAccountStore: AccountStore {
  private(set) var account: Account?
  private(set) var isRestoring = false

  private let client: APIClient

  init(client: APIClient) {
    self.client = client
  }

  /// Called once at launch. If a token pair is present, confirm it with `/me`
  /// (refreshing transparently); any failure leaves the app signed out.
  func restore() async {
    guard client.isAuthenticated else { return }
    isRestoring = true
    defer { isRestoring = false }
    do {
      let me: MeResponseDTO = try await client.request("/me")
      account = Self.account(from: me.user)
    } catch {
      account = nil
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
    account = Self.account(from: resp.user)
  }

  func logIn(email: String, password: String) async throws {
    let resp: AuthResponseDTO = try await client.request(
      "/auth/login",
      method: "POST",
      body: LoginRequestDTO(email: email, password: password),
      authorized: false
    )
    client.tokens.save(access: resp.accessToken, refresh: resp.refreshToken)
    account = Self.account(from: resp.user)
  }

  func logOut() async {
    _ = try? await client.request("/auth/logout", method: "POST", as: OKResponseDTO.self)
    client.tokens.clear()
    account = nil
  }

  func deleteAccount() async throws {
    _ = try await client.request("/me", method: "DELETE", as: OKResponseDTO.self)
    client.tokens.clear()
    account = nil
  }

  private static func account(from dto: UserDTO) -> Account {
    Account(displayName: dto.displayName, email: dto.email, method: .email, appleUserID: nil)
  }
}
