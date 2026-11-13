import Foundation

/// Errors surfaced by `APIClient`. `message` carries the backend's gentle,
/// user-facing copy where one exists, so screens can show it verbatim.
enum APIError: LocalizedError, Equatable {
  /// Not authenticated / refresh failed — the caller should treat as signed out.
  case unauthorized
  /// A non-2xx response with the backend's `{ error: { code, message } }`.
  case http(status: Int, code: String, message: String)
  /// Transport failure (offline, timeout, DNS).
  case transport(String)
  /// Response body didn't match the expected shape.
  case decoding(String)

  var errorDescription: String? {
    switch self {
    case .unauthorized:
      return String(localized: "Your session has ended. Please sign in again.", bundle: .app, locale: .app)
    case let .http(_, code, message):
      // The server's message is English; its code is the contract. The codes
      // a member meets on the signed-out screens are worded here, in the
      // reading language, and anything else still says what the server said.
      switch code {
      case "invalid_credentials":
        return String(localized: "Incorrect email or password", bundle: .app, locale: .app)
      case "email_taken":
        return String(localized: "Email already registered", bundle: .app, locale: .app)
      default:
        return message
      }
    case .transport:
      return String(localized: "We couldn't reach DEEP just now. Check your connection and try again.", bundle: .app, locale: .app)
    case .decoding:
      return String(localized: "Something looked off in the response. Please try again.", bundle: .app, locale: .app)
    }
  }
}
