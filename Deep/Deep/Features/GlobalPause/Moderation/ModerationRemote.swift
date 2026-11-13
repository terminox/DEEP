import Foundation

/// Why a member reported a peace message. The raw values are the wire values
/// `POST /pause/messages/:id/report` accepts.
enum PeaceMessageReportReason: String, CaseIterable, Identifiable, Sendable {
  case offensive
  case harassment
  case spam
  case other

  var id: String { rawValue }
}

/// Someone the member has blocked. `id` is the *block's* id — the blocked
/// member's own id never leaves the server — and `displayName` is their
/// current name, so the list stays recognisable after a rename.
struct BlockedMember: Identifiable, Hashable, Sendable {
  let id: String
  let displayName: String
  let createdAt: Date
}

/// The backend seam for keeping peace messages kind: reporting a message,
/// blocking its author, and the member's own block list. `ModerationStore`
/// depends on this protocol so previews and tests run against
/// `MockModerationRemote` with no network — the `PlaylistRemote` pattern.
///
/// Every call needs a signed-in member; the server answers a signed-out one
/// with a 401.
@MainActor
protocol ModerationRemote: AnyObject {
  /// Idempotent server-side: reporting the same message twice changes nothing.
  func report(messageID: String, reason: PeaceMessageReportReason) async throws
  /// Blocks the message's author. Nil when the author's account is gone —
  /// there is nobody left to list, so only the message itself is hidden.
  func blockAuthor(messageID: String) async throws -> BlockedMember?
  /// The member's blocks, newest first.
  func blockedMembers() async throws -> [BlockedMember]
  /// Lifts one block. Idempotent: an unknown id is a quiet success.
  func unblock(blockID: String) async throws
}

// MARK: - API

@MainActor
final class APIModerationRemote: ModerationRemote {
  private let client: APIClient

  init(client: APIClient) {
    self.client = client
  }

  func report(messageID: String, reason: PeaceMessageReportReason) async throws {
    try await client.request(
      "/pause/messages/\(messageID)/report",
      method: "POST",
      body: PeaceMessageReportRequestDTO(reason: reason.rawValue),
      as: OKResponseDTO.self
    )
  }

  func blockAuthor(messageID: String) async throws -> BlockedMember? {
    let dto: BlockAuthorResponseDTO = try await client.request(
      "/pause/messages/\(messageID)/block-author",
      method: "POST"
    )
    return dto.block.map(Self.member(from:))
  }

  func blockedMembers() async throws -> [BlockedMember] {
    let dto: BlockedMembersResponseDTO = try await client.request("/me/blocks")
    return dto.blocks.map(Self.member(from:))
  }

  func unblock(blockID: String) async throws {
    try await client.request(
      "/me/blocks/\(blockID)",
      method: "DELETE",
      as: OKResponseDTO.self
    )
  }

  // MARK: Mapping

  static func member(from dto: BlockedMemberDTO) -> BlockedMember {
    BlockedMember(
      id: dto.id,
      displayName: dto.displayName,
      createdAt: date(from: dto.createdAt) ?? .now
    )
  }

  // Fractional-second ISO first, then the plain form — the `APIPlaylistRemote`
  // parsing.
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

// MARK: - Mock

/// Hermetic stand-in for previews and tests: an in-memory block list that
/// behaves like the server (idempotent reports, newest-first blocks), with
/// per-call failure switches for the rollback paths and a record of what was
/// asked.
@MainActor
final class MockModerationRemote: ModerationRemote {
  struct Failure: Error {}

  var blocks: [BlockedMember]
  /// Author names by message id, so a block can name who it blocked. A message
  /// missing here blocks a deleted account (`nil`).
  var authors: [String: String]
  var failsReport = false
  var failsBlock = false
  var failsFetch = false
  var failsUnblock = false

  private(set) var reports: [(messageID: String, reason: PeaceMessageReportReason)] = []
  private(set) var blockedMessageIDs: [String] = []
  private(set) var unblockedIDs: [String] = []

  init(blocks: [BlockedMember] = [], authors: [String: String] = [:]) {
    self.blocks = blocks
    self.authors = authors
  }

  func report(messageID: String, reason: PeaceMessageReportReason) async throws {
    if failsReport { throw Failure() }
    reports.append((messageID, reason))
  }

  func blockAuthor(messageID: String) async throws -> BlockedMember? {
    if failsBlock { throw Failure() }
    blockedMessageIDs.append(messageID)
    guard let name = authors[messageID] else { return nil }
    if let existing = blocks.first(where: { $0.displayName == name }) { return existing }
    let block = BlockedMember(id: "block-\(messageID)", displayName: name, createdAt: .now)
    blocks.insert(block, at: 0)
    return block
  }

  func blockedMembers() async throws -> [BlockedMember] {
    if failsFetch { throw Failure() }
    return blocks
  }

  func unblock(blockID: String) async throws {
    if failsUnblock { throw Failure() }
    unblockedIDs.append(blockID)
    blocks.removeAll { $0.id == blockID }
  }
}

extension BlockedMember {
  /// Two blocks for previews and tests, newest first.
  static let samples: [BlockedMember] = [
    BlockedMember(id: "block-1", displayName: "Haruki", createdAt: Date().addingTimeInterval(-3600)),
    BlockedMember(id: "block-2", displayName: "Camille", createdAt: Date().addingTimeInterval(-86_400 * 3)),
  ]
}
