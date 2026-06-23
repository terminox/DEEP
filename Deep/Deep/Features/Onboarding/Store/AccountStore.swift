import SwiftUI
import Observation

/// The account surface the onboarding auth screens depend on. Kept free of any
/// `AuthenticationServices` import (the Apple result arrives as an
/// `AppleCredential`) so screens preview against `MockAccountStore`.
///
/// Auth is **local only** — there is no backend yet. `createAccount` validates
/// input and stores an `Account`, but never persists the raw password.
protocol AccountStore: AnyObject, Observable {
  var account: Account? { get }
  var isSignedIn: Bool { get }

  func signInWithApple(_ credential: AppleCredential)
  func createAccount(name: String, email: String, password: String) throws
  func signOut()
}

extension AccountStore {
  var isSignedIn: Bool { account != nil }
}

extension EnvironmentValues {
  @Entry var accountStore: any AccountStore = KeychainlessAccountStore()
}
