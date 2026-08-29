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

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HomeSectionHeader(title: "Peace messages")

      LazyVStack(alignment: .leading, spacing: 12) {
        ForEach(messages) { message in
          PeaceMessageCard(message: message, intentions: intentions)
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

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      PeaceMessageIdentity(
        name: message.displayName,
        place: message.countryName,
        tintSeed: message.id
      )

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
    .peaceMessageCard()
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel)
  }

  private var accessibilityLabel: String {
    var parts = [message.displayName]
    if !message.countryName.isEmpty { parts.append("from \(message.countryName)") }
    parts.append("says: \(message.text)")
    parts.append(message.createdAt.formatted(.relative(presentation: .named)))
    if let tag = message.intentionLabel(in: intentions) { parts.append("tagged \(tag)") }
    return parts.joined(separator: ", ")
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
