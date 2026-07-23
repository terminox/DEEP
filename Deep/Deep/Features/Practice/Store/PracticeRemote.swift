import Foundation

/// The backend seam for practice: offer completed sessions up, pull the full
/// log back down. The store depends on this protocol so previews and tests run
/// against `MockPracticeRemote`.
protocol PracticeRemote: AnyObject {
  /// Uploads completions and returns the ids the server has accepted.
  func upload(_ completions: [PracticeCompletion]) async throws -> [UUID]
  /// The server's whole log for the signed-in user, already marked synced.
  func fetchAll() async throws -> [PracticeCompletion]
}

/// Hermetic default for previews — accepts everything, remembers nothing.
@MainActor
final class MockPracticeRemote: PracticeRemote {
  func upload(_ completions: [PracticeCompletion]) async throws -> [UUID] {
    completions.map(\.id)
  }

  func fetchAll() async throws -> [PracticeCompletion] { [] }
}

/// Real implementation over `APIClient`.
@MainActor
final class APIPracticeRemote: PracticeRemote {
  private let client: APIClient

  init(client: APIClient) {
    self.client = client
  }

  func upload(_ completions: [PracticeCompletion]) async throws -> [UUID] {
    let dto: PracticeSyncResponseDTO = try await client.request(
      "/me/practice/sessions",
      method: "POST",
      body: PracticeSyncRequestDTO(sessions: completions.map { completion in
        PracticeSessionDTO(
          id: completion.id.uuidString,
          title: completion.title,
          durationSeconds: completion.durationSeconds,
          completedAt: Self.isoFormatter.string(from: completion.completedAt)
        )
      })
    )
    return dto.synced.compactMap(UUID.init(uuidString:))
  }

  func fetchAll() async throws -> [PracticeCompletion] {
    let dto: PracticeSessionsResponseDTO = try await client.request("/me/practice/sessions")
    return dto.sessions.compactMap { session in
      guard let id = UUID(uuidString: session.id),
            let completedAt = Self.date(from: session.completedAt)
      else { return nil }
      return PracticeCompletion(
        id: id,
        title: session.title,
        durationSeconds: session.durationSeconds,
        completedAt: completedAt,
        isSynced: true
      )
    }
  }

  // MARK: - Dates

  // `APIClient`'s coders carry no date strategy, so timestamps cross the wire
  // as ISO 8601 strings. Prisma's `toISOString()` includes milliseconds, hence
  // the fractional-seconds formatter — with a plain fallback for tolerance.

  private static let isoFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  private static let plainISOFormatter = ISO8601DateFormatter()

  private static func date(from string: String) -> Date? {
    isoFormatter.date(from: string) ?? plainISOFormatter.date(from: string)
  }
}
