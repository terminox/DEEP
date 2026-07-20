import Foundation
import Security

/// Stores the auth token pair in the Keychain — the deliberate upgrade from the
/// pre-backend `KeychainlessAccountStore`. Access + refresh tokens are the only
/// secrets kept; the `Account` identity itself is non-secret and lives with the
/// account store. Synchronous by design (Keychain calls are cheap and safe to
/// call from any actor).
final class KeychainTokenStore: Sendable {
  private let service: String

  init(service: String = (Bundle.main.bundleIdentifier ?? "io.appbeyond.freelance.Deep") + ".auth") {
    self.service = service
  }

  struct Tokens {
    let access: String
    let refresh: String
  }

  private enum Key: String {
    case access
    case refresh
  }

  var tokens: Tokens? {
    guard let access = read(.access), let refresh = read(.refresh) else { return nil }
    return Tokens(access: access, refresh: refresh)
  }

  var accessToken: String? { read(.access) }
  var refreshToken: String? { read(.refresh) }

  func save(access: String, refresh: String) {
    write(access, for: .access)
    write(refresh, for: .refresh)
  }

  func clear() {
    delete(.access)
    delete(.refresh)
  }

  // MARK: - Keychain primitives

  private func query(_ key: Key) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key.rawValue,
    ]
  }

  private func read(_ key: Key) -> String? {
    var q = query(key)
    q[kSecReturnData as String] = true
    q[kSecMatchLimit as String] = kSecMatchLimitOne
    var out: AnyObject?
    guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
          let data = out as? Data
    else { return nil }
    return String(data: data, encoding: .utf8)
  }

  private func write(_ value: String, for key: Key) {
    let data = Data(value.utf8)
    delete(key)
    var q = query(key)
    q[kSecValueData as String] = data
    q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
    SecItemAdd(q as CFDictionary, nil)
  }

  private func delete(_ key: Key) {
    SecItemDelete(query(key) as CFDictionary)
  }
}
