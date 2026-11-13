import SwiftUI

/// A titled vertical list of `PeaceMessage`s — the messages left around the
/// nightly pause, shown back to everyone in Fuku's Lounge. Full-width cards,
/// lazily built; the owner keeps appending pages via `onReachEnd` as the last
/// card scrolls into view.
struct PeaceMessagesSection: View {
  let messages: [PeaceMessage]
  /// Tonight's intention options, used to read a message's tag back as the
  /// label the member chose. Empty falls back to the humanised key.
  var intentions: [Intention] = []
  var isLoadingMore = false
  var onReachEnd: () -> Void = {}
  /// Whether a card offers Report and Block: the owner answers per message
  /// (signed in, and not the member's own). Off by default, so a section with
  /// no owner to act on the choice never offers one.
  var canModerate: (PeaceMessage) -> Bool = { _ in false }
  var onReport: (PeaceMessage, PeaceMessageReportReason) -> Void = { _, _ in }
  var onBlock: (PeaceMessage) -> Void = { _ in }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HomeSectionHeader(title: "Peace messages")

      LazyVStack(alignment: .leading, spacing: 12) {
        ForEach(messages) { message in
          PeaceMessageCard(
            message: message,
            intentions: intentions,
            menu: canModerate(message)
              ? PeaceMessageMenuActions(
                report: { onReport(message, $0) },
                block: { onBlock(message) }
              )
              : nil
          )
            .onAppear {
              if message.id == messages.last?.id { onReachEnd() }
            }
        }

        if isLoadingMore {
          ProgressView()
            .tint(.driftGrey)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
      }
      .padding(.horizontal, .edge)
    }
  }
}

/// One message: who and where from, the quote, when it was left, and the word
/// it was tagged with. Shares its chrome with `PeaceMessageComposerCard`, so
/// what a member writes into is exactly what the world reads back.
private struct PeaceMessageCard: View {
  let message: PeaceMessage
  let intentions: [Intention]
  /// Nil when this card offers no menu — signed out, or the member's own.
  var menu: PeaceMessageMenuActions?

  /// The report reasons are showing. Held here so the picker can be anchored
  /// to this card's own ellipsis (iOS presents it as a popover from the view
  /// it hangs on), whether the menu or VoiceOver asked for it.
  @State private var isChoosingReason = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      PeaceMessageIdentity(
        name: message.displayName,
        place: message.countryName,
        tintSeed: message.id
      )
      // Room for the menu, which floats over this row rather than sitting in
      // it, so the rest of the card can still be read as one element.
      .padding(.trailing, menu == nil ? 0 : 30)

      Text("\u{201C}\(message.text)\u{201D}")
        .font(DeepType.caption)
        .foregroundStyle(Color.deepPlum.opacity(0.78))
        .lineSpacing(2)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)

      HStack(alignment: .center, spacing: 8) {
        Text(message.createdAt, format: .relative(presentation: .named))
          .font(DeepType.micro)
          .foregroundStyle(.driftGrey)
          // Not a Spacer — see `PeaceMessageIdentity`.
          .frame(maxWidth: .infinity, alignment: .leading)

        if let tag = message.intentionLabel(in: intentions) {
          DeepTagLabel(label: tag)
        }
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityActions {
      if let menu {
        Button("Report") { isChoosingReason = true }
        Button("Block \(message.displayName)", action: menu.block)
      }
    }
    .peaceMessageCard()
    .overlay(alignment: .topTrailing) {
      if let menu {
        PeaceMessageMenu(
          name: message.displayName,
          report: { isChoosingReason = true },
          block: menu.block
        )
        .confirmationDialog(
          "Report this message",
          isPresented: $isChoosingReason,
          titleVisibility: .visible
        ) {
          ForEach(PeaceMessageReportReason.allCases) { reason in
            Button(reason.title) { menu.report(reason) }
          }
          Button("Cancel", role: .cancel) {}
        }
        // Centres the glyph on the identity row: 14 of card padding plus
        // half the 32-point avatar, less half this 44-point target.
        .padding(.top, 8)
        .padding(.trailing, 2)
      }
    }
  }

  private var accessibilityLabel: String {
    var parts = [message.displayName]
    if !message.countryName.isEmpty {
      parts.append(String(localized: "from \(message.countryName)", bundle: .app, locale: .app))
    }
    parts.append(String(localized: "says: \(message.text)", bundle: .app, locale: .app))
    parts.append(message.createdAt.formatted(.relative(presentation: .named).locale(.app)))
    if let tag = message.intentionLabel(in: intentions) {
      parts.append(String(localized: "tagged \(tag)", bundle: .app, locale: .app))
    }
    return parts.joined(separator: ", ")
  }
}

/// What a card's menu does, handed down by the section's owner. Reporting
/// arrives with its reason, chosen on the card; blocking asks the owner, who
/// confirms it.
struct PeaceMessageMenuActions {
  let report: (PeaceMessageReportReason) -> Void
  let block: () -> Void
}

extension PeaceMessageReportReason {
  /// The reason as the picker shows it.
  var title: LocalizedStringKey {
    switch self {
    case .offensive: "Offensive"
    case .harassment: "Harassment"
    case .spam: "Spam"
    case .other: "Something else"
    }
  }
}

/// The quiet "more" control on someone else's message: Report, and Block
/// their author. Neither item is `.destructive`: that would paint it the
/// system's alarm red, and DEEP has no urgent reds. The confirmation that
/// follows each one is where the weight sits.
struct PeaceMessageMenu: View {
  let name: String
  let report: () -> Void
  let block: () -> Void

  var body: some View {
    Menu {
      Button(action: report) {
        Label("Report", systemImage: "flag")
      }
      Button(action: block) {
        Label("Block \(name)", systemImage: "hand.raised")
      }
    } label: {
      Image(systemName: "ellipsis")
        .font(DeepType.body)
        .foregroundStyle(.driftGrey)
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }
    .menuIndicator(.hidden)
    .accessibilityLabel("More")
  }
}

#Preview("Peace Messages") {
  ScrollView {
    PeaceMessagesSection(
      messages: FixturePauseEventRepository.sampleMessages,
      intentions: Intention.samples
    )
    .padding(.vertical, 24)
  }
  .background { AtmosphereBackground() }
}

#Preview("Signed in — with menus") {
  ScrollView {
    PeaceMessagesSection(
      messages: FixturePauseEventRepository.sampleMessages,
      intentions: Intention.samples,
      canModerate: { $0.id != "fixture-1" }
    )
    .padding(.vertical, 24)
  }
  .background { AtmosphereBackground() }
}

#Preview("More menu") {
  ZStack {
    AtmosphereBackground()
    PeaceMessageMenu(name: "Haruki", report: {}, block: {})
  }
}

#Preview("Loading more") {
  ScrollView {
    PeaceMessagesSection(
      messages: FixturePauseEventRepository.sampleMessages,
      intentions: Intention.samples,
      isLoadingMore: true
    )
    .padding(.vertical, 24)
  }
  .background { AtmosphereBackground() }
}
