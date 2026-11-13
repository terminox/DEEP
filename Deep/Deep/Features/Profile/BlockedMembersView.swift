import SwiftUI

/// The members this person has blocked, pushed from Settings. One card of
/// names, each with its own Unblock; lifting a block takes the row away at
/// once and brings it back if the server refuses.
///
/// Composed from the Settings parts (`SettingsSection`, `SettingsRow`), with
/// the playlist's bare-words empty state and frosted-chip retry, so it reads as
/// part of Settings rather than a screen of its own making.
struct BlockedMembersView: View {
  @Environment(\.moderationStore) private var moderation

  @State private var unblockFailed = false

  var body: some View {
    ZStack {
      AtmosphereBackground()

      ScrollView {
        content
          .padding(.horizontal, .edge)
          .padding(.top, .rhythm)
          .padding(.bottom, 40)
      }
      .scrollIndicators(.hidden)
    }
    .navigationTitle("Blocked members")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.hidden, for: .navigationBar)
    .task { await moderation.loadBlockedMembers() }
    .animation(.settle, value: moderation.blockedMembers)
    .animation(.settle, value: unblockFailed)
  }

  @ViewBuilder
  private var content: some View {
    switch moderation.blockedMembersPhase {
    case .idle, .loading:
      ProgressView()
        .tint(.driftGrey)
        .frame(maxWidth: .infinity)
        .padding(.top, 72)
    case .failed:
      failure
    case .loaded where moderation.blockedMembers.isEmpty:
      empty
    case .loaded:
      list
    }
  }

  private var list: some View {
    VStack(alignment: .leading, spacing: 10) {
      SettingsSection {
        ForEach(moderation.blockedMembers) { member in
          SettingsRow(
            icon: "person.crop.circle.badge.xmark",
            verbatim: member.displayName,
            accessory: moderation.unblockingIDs.contains(member.id)
              ? .progress
              : .value(String(localized: "Unblock", bundle: .app, locale: .app))
          ) {
            unblock(member)
          }
          .accessibilityHint("Unblocks \(member.displayName)")
        }
      }
      Text(footnote)
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey)
        .padding(.horizontal, 8)
        .contentTransition(.opacity)
    }
  }

  /// What lifting a block does, or that the last one didn't go through.
  /// Spelled as keys so both resolve through the String Catalog.
  private var footnote: LocalizedStringKey {
    unblockFailed
      ? "Something went wrong. Please try again."
      : "Unblocked members' peace messages will show again."
  }

  /// Bare words on the atmosphere, as the playlist's empty state has them —
  /// having blocked nobody is the normal case, not a fault.
  private var empty: some View {
    Text("You haven't blocked anyone.")
      .font(DeepType.body)
      .foregroundStyle(.driftGrey)
      .multilineTextAlignment(.center)
      .frame(maxWidth: .infinity)
      .padding(.top, 72)
  }

  private var failure: some View {
    VStack(spacing: 14) {
      Text("We couldn't load your blocked members.")
        .font(DeepType.body)
        .foregroundStyle(.driftGrey)
        .multilineTextAlignment(.center)
      Button {
        Task { await moderation.loadBlockedMembers() }
      } label: {
        Text("Try again")
          .font(DeepType.body.weight(.medium))
          .foregroundStyle(.deepPlum)
          .padding(.horizontal, 22)
          .padding(.vertical, 12)
          .frostedCard(cornerRadius: .chip)
      }
      .buttonStyle(.softPress)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 48)
  }

  private func unblock(_ member: BlockedMember) {
    unblockFailed = false
    Task {
      do {
        try await moderation.unblock(member)
      } catch {
        unblockFailed = true
      }
    }
  }
}

#if DEBUG
#Preview("Blocked members — two") {
  NavigationStack {
    BlockedMembersView()
      .environment(\.moderationStore, ModerationStore(remote: MockModerationRemote(blocks: BlockedMember.samples)))
  }
}

#Preview("Blocked members — empty") {
  NavigationStack {
    BlockedMembersView()
      .environment(\.moderationStore, ModerationStore(remote: MockModerationRemote()))
  }
}

#Preview("Blocked members — failed") {
  let remote = MockModerationRemote()
  remote.failsFetch = true
  return NavigationStack {
    BlockedMembersView()
      .environment(\.moderationStore, ModerationStore(remote: remote))
  }
}
#endif
