#if DEBUG
import Foundation
import Observation

/// In-memory `AccountStore` for previews and tests. Sign-up validates exactly
/// like the real store but persists nothing.
@MainActor
@Observable
final class MockAccountStore: AccountStore {
  private(set) var account: Account?

  init(account: Account? = nil) {
    self.account = account
  }

  func signInWithApple(_ credential: AppleCredential) {
    account = Account(
      displayName: "Miyu",
      email: credential.email,
      method: .apple,
      appleUserID: credential.userID
    )
  }

  func createAccount(name: String, email: String, password: String) throws {
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty else { throw AccountError.emptyName }
    guard email.contains("@"), email.contains(".") else { throw AccountError.invalidEmail }
    guard password.count >= 8 else { throw AccountError.weakPassword }
    account = Account(displayName: trimmedName, email: email, method: .email, appleUserID: nil)
  }

  func signOut() {
    account = nil
  }
}

extension MockAccountStore {
  static var signedOut: MockAccountStore { MockAccountStore() }

  static var appleUser: MockAccountStore {
    MockAccountStore(account: Account(displayName: "Miyu", email: nil, method: .apple, appleUserID: "x"))
  }

  static var emailUser: MockAccountStore {
    MockAccountStore(account: Account(displayName: "Alex", email: "alex@deep.app", method: .email, appleUserID: nil))
  }
}
#endif
