import Testing
import Foundation
@testable import Deep

/// `APIClient.apiError(from:status:)` is the seam that decides which 401s end
/// a session. Only `unauthorized` (an expired/invalid/missing token) and
/// `token_reuse` (a revoked refresh token) should become `.unauthorized` —
/// everything else, notably `invalid_credentials` from a bad login attempt,
/// must surface as `.http` so the caller can show the server's own message
/// instead of "Your session has ended."
struct APIClientTests {
  private func envelope(code: String, message: String) -> Data {
    Data("{\"error\":{\"code\":\"\(code)\",\"message\":\"\(message)\"}}".utf8)
  }

  @Test("A 401 with code unauthorized ends the session")
  func unauthorizedCodeEndsSession() {
    let data = envelope(code: "unauthorized", message: "Invalid or expired token")
    #expect(APIClient.apiError(from: data, status: 401) == .unauthorized)
  }

  @Test("A 401 with code token_reuse ends the session")
  func tokenReuseEndsSession() {
    let data = envelope(code: "token_reuse", message: "Refresh token reuse detected")
    #expect(APIClient.apiError(from: data, status: 401) == .unauthorized)
  }

  @Test("A 401 with code invalid_credentials surfaces the server's message")
  func invalidCredentialsSurfacesMessage() {
    let data = envelope(code: "invalid_credentials", message: "Incorrect email or password")
    #expect(
      APIClient.apiError(from: data, status: 401)
        == .http(status: 401, code: "invalid_credentials", message: "Incorrect email or password")
    )
  }

  @Test("A 401 with an unparseable body still ends the session")
  func unparseableBodyEndsSession() {
    let data = Data("not json".utf8)
    #expect(APIClient.apiError(from: data, status: 401) == .unauthorized)
  }

  @Test("A non-401 error keeps its own status and code")
  func nonAuthErrorKeepsStatus() {
    let data = envelope(code: "not_found", message: "That plant doesn't exist")
    #expect(
      APIClient.apiError(from: data, status: 404)
        == .http(status: 404, code: "not_found", message: "That plant doesn't exist")
    )
  }
}
