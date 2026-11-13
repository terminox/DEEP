import SwiftUI
import Observation

/// What this member has asked not to see, shared by every screen that shows a
/// peace message and by Settings' block list.
///
/// A reported or blocked message leaves the feed the moment the member acts:
/// its id goes into `hiddenMessageIDs` first, and every feed filters through
/// `visible(_:)`. If the server then refuses, the id comes back out and the
/// call throws, so a message stays hidden only once the report or block has
/// landed. A block also bumps `blockRevision`; feeds watch it and refetch,
/// because the server knows which other messages that author left and this
/// phone does not.
///
/// A block-originated hide is filed under the block's id, so unblocking in
/// Settings brings that message back; a reported message stays hidden.
///
/// The server keeps the lasting record and filters the feeds for a signed-in
/// caller, so nothing here is persisted. It only covers the time until the next
/// fetch.
@MainActor
@Observable
final class ModerationStore {
  enum BlockedMembersPhase: Equatable {
    case idle, loading, loaded, failed
  }

  /// Messages reported or blocked on this phone since launch.
  var hiddenMessageIDs: Set<String> {
    blockHiddenMessageIDs.values.reduce(reportedMessageIDs.union(pendingBlockMessageIDs)) {
      $0.union($1)
    }
  }
  /// Reported messages, and blocked ones whose author's account is gone (there
  /// is no block to lift). These stay hidden until the next launch.
  private var reportedMessageIDs: Set<String> = []
  /// Messages hidden by a block that hasn't landed yet.
  private var pendingBlockMessageIDs: Set<String> = []
  /// Messages hidden by a landed block, keyed by the block's id, so an unblock
  /// can show them again.
  private var blockHiddenMessageIDs: [String: Set<String>] = [:]
  /// Bumped each time a block or unblock lands, so feeds can refetch.
  private(set) var blockRevision = 0

  /// The member's blocks, newest first. Empty until the first load.
  private(set) var blockedMembers: [BlockedMember] = []
  private(set) var blockedMembersPhase: BlockedMembersPhase = .idle
  /// Blocks with an unblock on the way, so their rows can show progress and
  /// refuse a second tap.
  private(set) var unblockingIDs: Set<String> = []

  @ObservationIgnored private let remote: any ModerationRemote

  init(remote: any ModerationRemote) {
    self.remote = remote
  }

  // MARK: - Feeds

  /// The messages a feed should show: everything but what was hidden here.
  func visible(_ messages: [PeaceMessage]) -> [PeaceMessage] {
    guard !hiddenMessageIDs.isEmpty else { return messages }
    return messages.filter { !hiddenMessageIDs.contains($0.id) }
  }

  /// Hides the message right away and reports it. Throws, with the message
  /// shown again, if the server refuses.
  func report(_ message: PeaceMessage, reason: PeaceMessageReportReason) async throws {
    let wasReported = reportedMessageIDs.contains(message.id)
    reportedMessageIDs.insert(message.id)
    do {
      try await remote.report(messageID: message.id, reason: reason)
    } catch {
      if !wasReported { reportedMessageIDs.remove(message.id) }
      throw error
    }
  }

  /// Hides the message right away and blocks its author. On success the block
  /// joins the list (unless the author's account is gone) and `blockRevision`
  /// moves, so feeds refetch and drop the author's other messages. Throws, with
  /// the message shown again, if the server refuses.
  func block(_ message: PeaceMessage) async throws {
    let wasPending = pendingBlockMessageIDs.contains(message.id)
    pendingBlockMessageIDs.insert(message.id)
    do {
      let block = try await remote.blockAuthor(messageID: message.id)
      if !wasPending { pendingBlockMessageIDs.remove(message.id) }
      if let block {
        blockHiddenMessageIDs[block.id, default: []].insert(message.id)
        if !blockedMembers.contains(where: { $0.id == block.id }) {
          blockedMembers.insert(block, at: 0)
        }
      } else {
        reportedMessageIDs.insert(message.id)
      }
      blockRevision += 1
    } catch {
      if !wasPending { pendingBlockMessageIDs.remove(message.id) }
      throw error
    }
  }

  // MARK: - Block list

  /// Loads the block list. A failure keeps a list that is already on screen
  /// and only reports `.failed` when there is nothing to show.
  func loadBlockedMembers() async {
    guard blockedMembersPhase != .loading else { return }
    let hadList = blockedMembersPhase == .loaded
    if !hadList { blockedMembersPhase = .loading }
    do {
      blockedMembers = try await remote.blockedMembers()
      blockedMembersPhase = .loaded
    } catch {
      blockedMembersPhase = hadList ? .loaded : .failed
    }
  }

  /// Takes the block off the list right away and lifts it on the server. Once
  /// it lands, the messages this block hid here show again (unless they were
  /// also reported). If the server refuses, the row goes back where it was and
  /// the call throws.
  func unblock(_ member: BlockedMember) async throws {
    guard !unblockingIDs.contains(member.id) else { return }
    unblockingIDs.insert(member.id)
    defer { unblockingIDs.remove(member.id) }
    let index = blockedMembers.firstIndex(of: member)
    blockedMembers.removeAll { $0.id == member.id }
    do {
      try await remote.unblock(blockID: member.id)
      blockHiddenMessageIDs[member.id] = nil
      blockRevision += 1
    } catch {
      if let index, !blockedMembers.contains(where: { $0.id == member.id }) {
        blockedMembers.insert(member, at: min(index, blockedMembers.count))
      }
      throw error
    }
  }

  /// Forgets everything for the signed-out member, so the next account on
  /// this phone starts with nothing hidden.
  func resetLocalState() {
    reportedMessageIDs = []
    pendingBlockMessageIDs = []
    blockHiddenMessageIDs = [:]
    blockedMembers = []
    blockedMembersPhase = .idle
    unblockingIDs = []
  }
}

extension EnvironmentValues {
  /// Reporting, blocking and the block list. `AppDependencies` builds the live
  /// store; the default runs on the in-memory mock so previews stay hermetic.
  @Entry var moderationStore: ModerationStore = ModerationStore(remote: MockModerationRemote())
}
