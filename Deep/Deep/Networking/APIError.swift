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
      return "Your session has ended. Please sign in again."
    case let .http(_, _, message):
      return message
    case .transport:
      return "We couldn't reach Deep just now. Check your connection and try again."
    case .decoding:
      return "Something looked off in the response. Please try again."
    }
  }
}
