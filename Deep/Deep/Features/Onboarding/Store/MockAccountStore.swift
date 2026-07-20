#if DEBUG
import Foundation
import Observation

/// In-memory `AccountStore` for previews and tests — no networking, no
/// persistence. Sign-up/log-in fabricate a local `Account`.
@MainActor
@Observable
final class MockAccountStore: AccountStore {
  private(set) var account: Account?
  private(set) var isRestoring = false

  init(account: Account? = nil) {
    self.account = account
  }

  func restore() async {}

  func signUp(name: String, email: String, password: String) async throws {
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty else { throw AccountError.emptyName }
    guard email.contains("@"), email.contains(".") else { throw AccountError.invalidEmail }
    guard password.count >= 8 else { throw AccountError.weakPassword }
    account = Account(displayName: trimmedName, email: email, method: .email, appleUserID: nil)
  }

  func logIn(email: String, password: String) async throws {
    account = Account(displayName: "Alex", email: email, method: .email, appleUserID: nil)
  }

  func logOut() async {
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
