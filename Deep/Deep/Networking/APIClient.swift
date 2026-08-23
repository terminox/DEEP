import Foundation

/// The app's single HTTP seam to the Deep backend. Async/await over `URLSession`,
/// base URL from `AppConfig`, Bearer-token injection from the Keychain, and a
/// single transparent refresh-then-retry on a 401. Repositories and the auth
/// store are built on top of this; views never touch it directly.
@MainActor
final class APIClient {
  let baseURL: URL
  let tokens: KeychainTokenStore

  private let session: URLSession
  private let decoder = JSONDecoder()
  private let encoder = JSONEncoder()
  private var refreshTask: Task<Void, Error>?

  init(baseURL: URL, tokens: KeychainTokenStore, session: URLSession = APIClient.makeSession()) {
    self.baseURL = baseURL
    self.tokens = tokens
    self.session = session
  }

  /// Fail fast instead of the 60 s system default. Every flow in the app is
  /// best-effort with a foreground retry, so a dead host should surface in
  /// seconds — critical for device Dev builds pointing at a Mac that may be
  /// unreachable, but sane in production too.
  nonisolated static func makeSession() -> URLSession {
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 10
    configuration.timeoutIntervalForResource = 30
    configuration.waitsForConnectivity = false
    return URLSession(configuration: configuration)
  }

  var isAuthenticated: Bool { tokens.accessToken != nil }

  // MARK: - Requests

  @discardableResult
  func request<Response: Decodable>(
    _ path: String,
    method: String = "GET",
    body: (any Encodable)? = nil,
    authorized: Bool = true,
    as _: Response.Type = Response.self
  ) async throws -> Response {
    let data = try await send(
      path: path,
      method: method,
      bodyData: try encodeBody(body),
      contentType: "application/json",
      authorized: authorized,
      allowRefresh: authorized
    )
    return try decode(Response.self, from: data)
  }

  /// Multipart upload of raw file bytes under field name `file`.
  @discardableResult
  func upload<Response: Decodable>(
    _ path: String,
    fileData: Data,
    filename: String,
    mimeType: String,
    as _: Response.Type = Response.self
  ) async throws -> Response {
    let boundary = "Boundary-\(UUID().uuidString)"
    var body = Data()
    let dashes = "--\(boundary)\r\n"
    body.append(Data(dashes.utf8))
    body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".utf8))
    body.append(Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
    body.append(fileData)
    body.append(Data("\r\n--\(boundary)--\r\n".utf8))

    let data = try await send(
      path: path,
      method: "POST",
      bodyData: body,
      contentType: "multipart/form-data; boundary=\(boundary)",
      authorized: true,
      allowRefresh: true
    )
    return try decode(Response.self, from: data)
  }

  // MARK: - Core

  private func send(
    path: String,
    method: String,
    bodyData: Data?,
    contentType: String,
    authorized: Bool,
    allowRefresh: Bool
  ) async throws -> Data {
    guard let url = URL(string: baseURL.absoluteString + path) else {
      throw APIError.transport("Bad URL")
    }
    var req = URLRequest(url: url)
    req.httpMethod = method
    // The user's day boundary travels with every request: award day-keys and
    // "earned today" figures follow the device timezone server-side.
    req.setValue(TimeZone.current.identifier, forHTTPHeaderField: "X-Device-Timezone")
    if let bodyData {
      req.httpBody = bodyData
      req.setValue(contentType, forHTTPHeaderField: "Content-Type")
    }
    if authorized, let access = tokens.accessToken {
      req.setValue("Bearer \(access)", forHTTPHeaderField: "Authorization")
    }

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await session.data(for: req)
    } catch {
      throw APIError.transport(error.localizedDescription)
    }

    guard let http = response as? HTTPURLResponse else {
      throw APIError.transport("No HTTP response")
    }

    if http.statusCode == 401 && authorized && allowRefresh {
      try await refreshTokens()
      return try await send(
        path: path,
        method: method,
        bodyData: bodyData,
        contentType: contentType,
        authorized: authorized,
        allowRefresh: false
      )
    }

    guard (200..<300).contains(http.statusCode) else {
      throw apiError(from: data, status: http.statusCode)
    }
    return data
  }

  /// Single-flight refresh: concurrent 401s await one rotation. Tokens are
  /// cleared only when the server actually *rejects* the refresh (a 4xx) —
  /// a timeout or unreachable host is not a revoked session, and clearing on
  /// it would log the user out every time the backend blips.
  private func refreshTokens() async throws {
    if let existing = refreshTask {
      return try await existing.value
    }
    guard let refresh = tokens.refreshToken else { throw APIError.unauthorized }

    let task = Task { [weak self] () throws -> Void in
      guard let self else { return }
      defer { self.refreshTask = nil }
      let bodyData = try self.encodeBody(RefreshRequestDTO(refreshToken: refresh))
      let data = try await self.send(
        path: "/auth/refresh",
        method: "POST",
        bodyData: bodyData,
        contentType: "application/json",
        authorized: false,
        allowRefresh: false
      )
      let tokenResp = try self.decode(TokenResponseDTO.self, from: data)
      self.tokens.save(access: tokenResp.accessToken, refresh: tokenResp.refreshToken)
    }
    refreshTask = task
    do {
      try await task.value
    } catch {
      if Self.isAuthRejection(error) {
        tokens.clear()
        throw APIError.unauthorized
      }
      // Transport / server hiccup: keep the token pair, surface the real
      // error — the caller retries later with the session intact.
      throw error
    }
  }

  /// Whether an error is the server refusing the credentials themselves —
  /// the only failures that may end a session. Transport errors, 5xx, and
  /// malformed responses are outages, not revocations.
  static func isAuthRejection(_ error: Error) -> Bool {
    switch error {
    case APIError.unauthorized:
      return true
    case APIError.http(let status, _, _):
      return (400..<500).contains(status)
    default:
      return false
    }
  }

  // MARK: - Coding

  private func encodeBody(_ body: (any Encodable)?) throws -> Data? {
    guard let body else { return nil }
    do {
      return try encoder.encode(body)
    } catch {
      throw APIError.decoding("Failed to encode request body")
    }
  }

  private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
    if T.self == OKResponseDTO.self, data.isEmpty {
      return OKResponseDTO(ok: true) as! T
    }
    do {
      return try decoder.decode(T.self, from: data)
    } catch {
      throw APIError.decoding(String(describing: error))
    }
  }

  private func apiError(from data: Data, status: Int) -> APIError {
    if status == 401 { return .unauthorized }
    if let env = try? decoder.decode(APIErrorEnvelope.self, from: data) {
      return .http(status: status, code: env.error.code, message: env.error.message)
    }
    return .http(status: status, code: "http_\(status)", message: "Request failed (\(status)).")
  }
}
