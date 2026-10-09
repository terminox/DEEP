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

/// Serves canned responses by host and path, so the client's refresh path runs
/// for real with no network. Each test gets its own host, keeping parallel
/// tests apart.
private final class StubURLProtocol: URLProtocol {
  /// host → path → (status, JSON body). A missing path fails as a transport
  /// error — the outage case.
  nonisolated(unsafe) private static var routes: [String: [String: (Int, String)]] = [:]
  private static let lock = NSLock()

  static func serve(host: String, _ table: [String: (Int, String)]) {
    lock.withLock { routes[host] = table }
  }

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let url = request.url else { return }
    let route = Self.lock.withLock { Self.routes[url.host ?? ""]?[url.path] }
    guard let (status, body) = route else {
      client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
      return
    }
    let response = HTTPURLResponse(
      url: url,
      statusCode: status,
      httpVersion: nil,
      headerFields: ["Content-Type": "application/json"]
    )!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Data(body.utf8))
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}

/// The account switch leak: a session the *server* ended (rejected at launch,
/// or its refresh refused mid-use) used to clear only the tokens, so the
/// device kept the old account's queued listens and unsynced practice and
/// credited them to whoever signed in next. The account store now reports the
/// ending, once, so the app clears them as log out does — and never for an
/// outage.
@MainActor
struct SessionEndingTests {
  private static let unauthorized = (401, #"{"error":{"code":"unauthorized","message":"Invalid or expired token"}}"#)
  private static let tokenReuse = (401, #"{"error":{"code":"token_reuse","message":"Refresh token reuse detected"}}"#)
  private static let me = (200, #"{"user":{"id":"u1","email":"a@deep.test","displayName":"A","role":"user"}}"#)

  final class Counter {
    var count = 0
  }

  private struct Rig {
    let host: String
    let client: APIClient
    let store: APIAccountStore
    let tokens: KeychainTokenStore
    let ended: Counter
  }

  private func makeRig(_ table: [String: (Int, String)]) -> Rig {
    let host = "stub-\(UUID().uuidString.lowercased()).test"
    StubURLProtocol.serve(host: host, table)
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    let tokens = KeychainTokenStore(service: "deep.tests.\(UUID().uuidString)")
    tokens.save(access: "access", refresh: "refresh")
    let client = APIClient(
      baseURL: URL(string: "https://\(host)")!,
      tokens: tokens,
      session: URLSession(configuration: configuration)
    )
    let suite = "deep.tests.session.\(UUID().uuidString)"
    let store = APIAccountStore(client: client, defaults: UserDefaults(suiteName: suite)!)
    let ended = Counter()
    store.onSessionEnded = { ended.count += 1 }
    return Rig(host: host, client: client, store: store, tokens: tokens, ended: ended)
  }

  @Test("A session rejected at launch ends once, and says so")
  func restoreRejectionEndsSession() async {
    let rig = makeRig(["/me": Self.unauthorized, "/auth/refresh": Self.tokenReuse])
    defer { rig.tokens.clear() }

    await rig.store.restore()

    #expect(rig.ended.count == 1)
    #expect(rig.store.isSignedIn == false)
    #expect(rig.tokens.accessToken == nil)
  }

  @Test("A refresh refused mid-use signs out and says so")
  func midSessionRefreshRejectionEndsSession() async {
    let rig = makeRig(["/me": Self.me])
    defer { rig.tokens.clear() }
    await rig.store.restore()
    #expect(rig.store.isSignedIn)

    // Later the access token has expired, and the refresh is refused.
    StubURLProtocol.serve(
      host: rig.host,
      ["/me/sound/listens": Self.unauthorized, "/auth/refresh": Self.tokenReuse]
    )
    await #expect(throws: APIError.unauthorized) {
      try await rig.client.request("/me/sound/listens", method: "POST", as: OKResponseDTO.self)
    }

    #expect(rig.ended.count == 1)
    #expect(rig.store.isSignedIn == false)
  }

  @Test("An outage keeps the session — nothing is reset")
  func outageKeepsSession() async {
    // No routes at all: every request fails as a transport error.
    let rig = makeRig([:])
    defer { rig.tokens.clear() }

    await rig.store.restore()

    #expect(rig.ended.count == 0)
    #expect(rig.store.isSignedIn)
    #expect(rig.tokens.accessToken == "access")
  }
}
