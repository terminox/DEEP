import Foundation
import Observation

/// `AccountStore` that persists the `Account` as JSON in `UserDefaults`.
///
/// Named for what it *is*: a deliberately keychain-free, backend-free store for
/// this pre-server stage. It validates sign-up input and keeps only the
/// `Account` — **never the password**. When a real backend or RevenueCat/CRM
/// identity arrives, swap this conformer without touching the screens.
@MainActor
@Observable
final class KeychainlessAccountStore: AccountStore {
  private static let key = "deep.account"

  private(set) var account: Account? {
    didSet { persist() }
  }

  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    if let data = defaults.data(forKey: Self.key),
       let decoded = try? JSONDecoder().decode(Account.self, from: data) {
      account = decoded
    } else {
      account = nil
    }
  }

  func signInWithApple(_ credential: AppleCredential) {
    // Apple returns name/email only on the first authorization — preserve any
    // existing values rather than overwriting them with nil on later sign-ins.
    let existing = account
    let name = Self.formattedName(credential.fullName)
      ?? existing?.displayName.nilIfBlank
      ?? "friend"
    account = Account(
      displayName: name,
      email: credential.email ?? existing?.email,
      method: .apple,
      appleUserID: credential.userID
    )
  }

  func createAccount(name: String, email: String, password: String) throws {
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !trimmedName.isEmpty else { throw AccountError.emptyName }
    guard Self.isValidEmail(trimmedEmail) else { throw AccountError.invalidEmail }
    guard password.count >= 8 else { throw AccountError.weakPassword }

    // No backend: the password is validated and then discarded — only the
    // identity is stored.
    account = Account(
      displayName: trimmedName,
      email: trimmedEmail,
      method: .email,
      appleUserID: nil
    )
  }

  func signOut() {
    account = nil
  }

  private func persist() {
    guard let account, let data = try? JSONEncoder().encode(account) else {
      defaults.removeObject(forKey: Self.key)
      return
    }
    defaults.set(data, forKey: Self.key)
  }

  private static func formattedName(_ components: PersonNameComponents?) -> String? {
    guard let components else { return nil }
    let formatted = PersonNameComponentsFormatter.localizedString(from: components, style: .default)
    return formatted.nilIfBlank
  }

  private static func isValidEmail(_ email: String) -> Bool {
    // Pragmatic check — a single "@" with non-empty, dotted domain.
    let pattern = #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#
    return email.range(of: pattern, options: .regularExpression) != nil
  }
}

private extension String {
  var nilIfBlank: String? {
    let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
