import SwiftUI
import Observation

/// The account surface the auth screens depend on. Kept UI-framework-agnostic so
/// screens preview against `PreviewAccountStore` / `MockAccountStore` with no
/// networking. The real conformer (`APIAccountStore`) talks to the Deep backend
/// over `APIClient` and keeps the token pair in the Keychain.
///
/// Email/password only for now; the `Account.Method` enum leaves room for Apple
/// / Google to arrive later without reshaping this surface.
protocol AccountStore: AnyObject, Observable {
  var account: Account? { get }
  var isSignedIn: Bool { get }
  /// True while a launch-time session restore is in flight — the root view shows
  /// a calm loading state rather than flashing the welcome screen.
  var isRestoring: Bool { get }

  /// Load any persisted session and confirm it with the backend.
  func restore() async
  func signUp(name: String, email: String, password: String) async throws
  func logIn(email: String, password: String) async throws
  func logOut() async
}

extension AccountStore {
  var isSignedIn: Bool { account != nil }
}

/// Hermetic, in-memory default for previews and the environment default — never
/// touches the network. Sign-up/log-in just fabricate a local `Account`.
@MainActor
@Observable
final class PreviewAccountStore: AccountStore {
  private(set) var account: Account?
  private(set) var isRestoring = false

  init(account: Account? = nil) {
    self.account = account
  }

  func restore() async {}

  func signUp(name: String, email: String, password: String) async throws {
    account = Account(displayName: name, email: email, method: .email, appleUserID: nil)
  }

  func logIn(email: String, password: String) async throws {
    account = Account(displayName: "Friend", email: email, method: .email, appleUserID: nil)
  }

  func logOut() async {
    account = nil
  }
}

extension EnvironmentValues {
  @Entry var accountStore: any AccountStore = PreviewAccountStore()
}
