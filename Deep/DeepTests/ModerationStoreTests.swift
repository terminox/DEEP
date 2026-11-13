import Testing
import Foundation
@testable import Deep

/// The moderation store's contract: a reported or blocked message leaves every
/// feed the moment the member acts, and stays gone only if the server
/// accepted. A block also tells feeds to refetch, because only the server
/// knows the author's other messages. Unblocking takes the row off the list at
/// once and puts it back exactly where it was if the server refuses.
@MainActor
struct ModerationStoreTests {
  private static let haruki = FixturePauseEventRepository.sampleMessages[1]
  private static let camille = FixturePauseEventRepository.sampleMessages[2]

  private static func makeStore(
    blocks: [BlockedMember] = []
  ) -> (store: ModerationStore, remote: MockModerationRemote) {
    let remote = MockModerationRemote(
      blocks: blocks,
      authors: [haruki.id: haruki.displayName, camille.id: camille.displayName]
    )
    return (ModerationStore(remote: remote), remote)
  }

  // MARK: - Report

  @Test("A report hides the message and sends the reason")
  func reportHidesAndSends() async throws {
    let (store, remote) = Self.makeStore()
    let feed = FixturePauseEventRepository.sampleMessages

    try await store.report(Self.haruki, reason: .harassment)

    #expect(store.hiddenMessageIDs == [Self.haruki.id])
    #expect(!store.visible(feed).contains(Self.haruki))
    #expect(store.visible(feed).count == feed.count - 1)
    #expect(remote.reports.map(\.messageID) == [Self.haruki.id])
    #expect(remote.reports.map(\.reason) == [.harassment])
    // A report hides one message; it never asks the feeds to refetch.
    #expect(store.blockRevision == 0)
  }

  @Test("A refused report brings the message back and throws")
  func refusedReportRestores() async {
    let (store, remote) = Self.makeStore()
    remote.failsReport = true

    await #expect(throws: MockModerationRemote.Failure.self) {
      try await store.report(Self.haruki, reason: .spam)
    }
    #expect(store.hiddenMessageIDs.isEmpty)
    #expect(store.visible([Self.haruki]) == [Self.haruki])
  }

  @Test("A refused second report keeps a message the first one hid")
  func refusedRepeatKeepsEarlierHide() async throws {
    let (store, remote) = Self.makeStore()
    try await store.report(Self.haruki, reason: .offensive)
    remote.failsReport = true

    await #expect(throws: MockModerationRemote.Failure.self) {
      try await store.report(Self.haruki, reason: .other)
    }
    #expect(store.hiddenMessageIDs == [Self.haruki.id])
  }

  // MARK: - Block

  @Test("A block hides the message, lists the author first, and asks feeds to refetch")
  func blockHidesListsAndBumps() async throws {
    let (store, remote) = Self.makeStore(blocks: Array(BlockedMember.samples.suffix(1)))
    await store.loadBlockedMembers()

    try await store.block(Self.haruki)

    #expect(store.hiddenMessageIDs == [Self.haruki.id])
    #expect(store.blockedMembers.first?.displayName == "Haruki")
    #expect(store.blockedMembers.count == 2)
    #expect(store.blockRevision == 1)
    #expect(remote.blockedMessageIDs == [Self.haruki.id])
  }

  @Test("Blocking a deleted account hides the message but lists nobody")
  func blockOfDeletedAccount() async throws {
    let (store, _) = Self.makeStore()
    let orphan = FixturePauseEventRepository.sampleMessages[5] // no author on record

    try await store.block(orphan)

    #expect(store.hiddenMessageIDs == [orphan.id])
    #expect(store.blockedMembers.isEmpty)
    #expect(store.blockRevision == 1)
  }

  @Test("Blocking the same author twice lists them once")
  func repeatBlockListsOnce() async throws {
    let (store, _) = Self.makeStore()

    try await store.block(Self.haruki)
    try await store.block(Self.haruki)

    #expect(store.blockedMembers.filter { $0.displayName == "Haruki" }.count == 1)
  }

  @Test("A refused block brings the message back, lists nobody, and leaves feeds alone")
  func refusedBlockRestores() async {
    let (store, remote) = Self.makeStore()
    remote.failsBlock = true

    await #expect(throws: MockModerationRemote.Failure.self) {
      try await store.block(Self.camille)
    }
    #expect(store.hiddenMessageIDs.isEmpty)
    #expect(store.blockedMembers.isEmpty)
    #expect(store.blockRevision == 0)
  }

  // MARK: - Block list

  @Test("Loading adopts the server's blocks, newest first")
  func loadAdoptsBlocks() async {
    let (store, _) = Self.makeStore(blocks: BlockedMember.samples)
    #expect(store.blockedMembersPhase == .idle)

    await store.loadBlockedMembers()

    #expect(store.blockedMembersPhase == .loaded)
    #expect(store.blockedMembers == BlockedMember.samples)
  }

  @Test("A first load that fails asks to be retried")
  func failedFirstLoad() async {
    let (store, remote) = Self.makeStore(blocks: BlockedMember.samples)
    remote.failsFetch = true

    await store.loadBlockedMembers()

    #expect(store.blockedMembersPhase == .failed)
    #expect(store.blockedMembers.isEmpty)
  }

  @Test("A failed reload keeps the list already on screen")
  func failedReloadKeepsList() async {
    let (store, remote) = Self.makeStore(blocks: BlockedMember.samples)
    await store.loadBlockedMembers()
    remote.failsFetch = true

    await store.loadBlockedMembers()

    #expect(store.blockedMembersPhase == .loaded)
    #expect(store.blockedMembers == BlockedMember.samples)
  }

  @Test("Unblocking removes the row and lifts the block on the server")
  func unblockRemoves() async throws {
    let (store, remote) = Self.makeStore(blocks: BlockedMember.samples)
    await store.loadBlockedMembers()

    try await store.unblock(BlockedMember.samples[0])

    #expect(store.blockedMembers == [BlockedMember.samples[1]])
    #expect(remote.unblockedIDs == [BlockedMember.samples[0].id])
    #expect(store.blockRevision == 1)
    #expect(store.unblockingIDs.isEmpty)
  }

  @Test("A refused unblock puts the row back where it was and throws")
  func refusedUnblockRestoresPosition() async {
    let (store, remote) = Self.makeStore(blocks: BlockedMember.samples)
    await store.loadBlockedMembers()
    remote.failsUnblock = true

    await #expect(throws: MockModerationRemote.Failure.self) {
      try await store.unblock(BlockedMember.samples[1])
    }
    #expect(store.blockedMembers == BlockedMember.samples)
    #expect(store.blockRevision == 0)
    #expect(store.unblockingIDs.isEmpty)
  }

  // MARK: - Sign out

  @Test("Signing out forgets what was hidden and who was blocked")
  func resetForgetsEverything() async throws {
    let (store, _) = Self.makeStore(blocks: BlockedMember.samples)
    await store.loadBlockedMembers()
    try await store.report(Self.haruki, reason: .spam)

    store.resetLocalState()

    #expect(store.hiddenMessageIDs.isEmpty)
    #expect(store.blockedMembers.isEmpty)
    #expect(store.blockedMembersPhase == .idle)
  }
}

/// The wire side: the moderation endpoints are called at the paths and with
/// the bodies the shared contract names, `isMine` decodes with a default of
/// false for older servers, and the content filter's 422 reaches the composer
/// as `message_rejected`.
@MainActor
struct ModerationWireTests {
  private func makeRemote(
    _ table: [String: (Int, String)]
  ) -> (remote: APIModerationRemote, host: String, tokens: KeychainTokenStore) {
    let host = "moderation-\(UUID().uuidString.lowercased()).test"
    ModerationStubURLProtocol.serve(host: host, table)
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [ModerationStubURLProtocol.self]
    let tokens = KeychainTokenStore(service: "deep.tests.\(UUID().uuidString)")
    tokens.save(access: "access", refresh: "refresh")
    let client = APIClient(
      baseURL: URL(string: "https://\(host)")!,
      tokens: tokens,
      session: URLSession(configuration: configuration)
    )
    return (APIModerationRemote(client: client), host, tokens)
  }

  @Test("A report posts the reason to the message's report path")
  func reportPostsReason() async throws {
    let (remote, host, tokens) = makeRemote([
      "POST /pause/messages/m-1/report": (200, #"{"ok":true}"#),
    ])
    defer { tokens.clear() }

    try await remote.report(messageID: "m-1", reason: .harassment)

    let sent = ModerationStubURLProtocol.lastBody(host: host)
    let json = try #require(sent.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: String] })
    #expect(json == ["reason": "harassment"])
  }

  @Test("A block answers with the blocked member")
  func blockReturnsMember() async throws {
    let (remote, _, tokens) = makeRemote([
      "POST /pause/messages/m-2/block-author": (
        200,
        #"{"ok":true,"block":{"id":"b-1","displayName":"Haruki","createdAt":"2026-11-12T08:10:00.000Z"}}"#
      ),
    ])
    defer { tokens.clear() }

    let block = try await remote.blockAuthor(messageID: "m-2")

    #expect(block?.id == "b-1")
    #expect(block?.displayName == "Haruki")
  }

  @Test("Blocking a deleted account answers nil")
  func blockOfDeletedAccountIsNil() async throws {
    let (remote, _, tokens) = makeRemote([
      "POST /pause/messages/m-3/block-author": (200, #"{"ok":true,"block":null}"#),
    ])
    defer { tokens.clear() }

    #expect(try await remote.blockAuthor(messageID: "m-3") == nil)
  }

  @Test("The block list decodes newest first, and unblock deletes by block id")
  func listAndUnblock() async throws {
    let (remote, _, tokens) = makeRemote([
      "GET /me/blocks": (
        200,
        #"{"blocks":[{"id":"b-2","displayName":"Camille","createdAt":"2026-11-12T08:10:00Z"},{"id":"b-1","displayName":"Haruki","createdAt":"2026-11-10T08:10:00.000Z"}]}"#
      ),
      "DELETE /me/blocks/b-2": (200, #"{"ok":true}"#),
    ])
    defer { tokens.clear() }

    let blocks = try await remote.blockedMembers()
    #expect(blocks.map(\.id) == ["b-2", "b-1"])
    #expect(blocks[0].createdAt > blocks[1].createdAt)

    try await remote.unblock(blockID: "b-2")
  }

  @Test("Reporting your own message surfaces own_message")
  func ownMessageSurfaces() async {
    let (remote, _, tokens) = makeRemote([
      "POST /pause/messages/m-4/report": (
        400,
        #"{"error":{"code":"own_message","message":"You can't report your own message."}}"#
      ),
    ])
    defer { tokens.clear() }

    await #expect(
      throws: APIError.http(status: 400, code: "own_message", message: "You can't report your own message.")
    ) {
      try await remote.report(messageID: "m-4", reason: .spam)
    }
  }

  @Test("isMine decodes, and defaults to false when an older server omits it")
  func isMineDecodes() throws {
    let base = #""id":"m","displayName":"Nan","countryISO":"TH","text":"Peace","createdAt":"2026-11-12T08:10:00Z""#
    let decoder = JSONDecoder()

    let legacy = try decoder.decode(PeaceMessageDTO.self, from: Data("{\(base)}".utf8))
    let mine = try decoder.decode(PeaceMessageDTO.self, from: Data("{\(base),\"isMine\":true}".utf8))
    let theirs = try decoder.decode(PeaceMessageDTO.self, from: Data("{\(base),\"isMine\":false}".utf8))

    #expect(legacy.isMine == false)
    #expect(legacy.intention == nil)
    #expect(mine.isMine)
    #expect(theirs.isMine == false)
  }

  @Test("The content filter's 422 arrives as message_rejected")
  func rejectedMessageMaps() {
    let data = Data(#"{"error":{"code":"message_rejected","message":"Please keep it kind."}}"#.utf8)
    #expect(
      APIClient.apiError(from: data, status: 422)
        == .http(status: 422, code: "message_rejected", message: "Please keep it kind.")
    )
  }
}

/// Serves canned responses by host and "METHOD /path", and remembers the last
/// request body per host so a test can read what was sent. Each test gets its
/// own host, keeping parallel tests apart.
private final class ModerationStubURLProtocol: URLProtocol {
  nonisolated(unsafe) private static var routes: [String: [String: (Int, String)]] = [:]
  nonisolated(unsafe) private static var bodies: [String: Data] = [:]
  private static let lock = NSLock()

  static func serve(host: String, _ table: [String: (Int, String)]) {
    lock.withLock { routes[host] = table }
  }

  static func lastBody(host: String) -> Data? {
    lock.withLock { bodies[host] }
  }

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let url = request.url, let host = url.host else { return }
    let key = "\(request.httpMethod ?? "GET") \(url.path)"
    let body = request.httpBody ?? request.httpBodyStream.map(Self.read)
    let route = Self.lock.withLock { () -> (Int, String)? in
      if let body { Self.bodies[host] = body }
      return Self.routes[host]?[key]
    }
    guard let (status, json) = route else {
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
    client?.urlProtocol(self, didLoad: Data(json.utf8))
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}

  /// URLSession hands a protocol its body as a stream; drain it.
  nonisolated private static func read(_ stream: InputStream) -> Data {
    stream.open()
    defer { stream.close() }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 1024)
    while stream.hasBytesAvailable {
      let count = stream.read(&buffer, maxLength: buffer.count)
      guard count > 0 else { break }
      data.append(buffer, count: count)
    }
    return data
  }
}
