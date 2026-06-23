import Foundation

/// The locally-stored account. There is no backend yet: this captures who the
/// user is so the app can greet them and, later, attach a CRM / subscription
/// identity. A raw password is **never** stored (see `AccountStore`).
struct Account: Codable, Equatable {
  enum Method: String, Codable {
    case apple
    case email
  }

  var displayName: String
  var email: String?
  var method: Method
  /// `ASAuthorizationAppleIDCredential.user` — stable across sign-ins, present
  /// only for Apple accounts.
  var appleUserID: String?
}

/// A framework-agnostic projection of an Apple sign-in result, so `AccountStore`
/// stays free of an `AuthenticationServices` import and remains previewable. The
/// auth screen maps `ASAuthorizationAppleIDCredential` into this value.
struct AppleCredential: Equatable {
  let userID: String
  var fullName: PersonNameComponents?
  var email: String?
}

/// Validation failures surfaced inline by the email sign-up form.
enum AccountError: LocalizedError, Equatable {
  case emptyName
  case invalidEmail
  case weakPassword

  var errorDescription: String? {
    switch self {
    case .emptyName: return "Please share a name we can call you."
    case .invalidEmail: return "That email doesn't look quite right."
    case .weakPassword: return "Use at least 8 characters."
    }
  }
}
