import SwiftUI

/// A titled, horizontally scrolling shelf of `PeaceMessage`s — the messages
/// left during the feedback phase, shown back to everyone in Fuku's Lounge.
struct PeaceMessagesSection: View {
  let messages: [PeaceMessage]

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HomeSectionHeader(title: "Peace messages")

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: 16) {
          ForEach(messages) { message in
            PeaceMessageCard(message: message)
          }
        }
        .padding(.horizontal, .edge)
      }
      .scrollClipDisabled()
      .scrollBounceBehavior(.basedOnSize)
    }
  }
}

/// One message: author, quote, and how long ago it was posted.
private struct PeaceMessageCard: View {
  let message: PeaceMessage

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .center, spacing: 8) {
        PeaceMessageAvatar(
          tint: Self.tint(for: message.id),
          initial: message.displayName.first.map(String.init) ?? "?"
        )
        .frame(width: 32, height: 32)

        Text(message.displayName)
          .font(DeepType.body.weight(.medium))
          .foregroundStyle(.deepPlum)
          .lineLimit(1)
      }

      Text("\u{201C}\(message.text)\u{201D}")
        .font(DeepType.caption)
        .foregroundStyle(Color.deepPlum.opacity(0.78))
        .lineSpacing(2)
        .multilineTextAlignment(.leading)
        .lineLimit(3)
        .frame(maxWidth: .infinity, alignment: .leading)

      Text(message.createdAt, format: .relative(presentation: .named))
        .font(DeepType.micro)
        .foregroundStyle(.driftGrey)
    }
    .padding(14)
    .frame(width: 240, alignment: .leading)
    .frostedCard(cornerRadius: 20)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "\(message.displayName) says: \(message.text), "
      + "\(message.createdAt.formatted(.relative(presentation: .named)))"
    )
  }

  /// Hashes the id into one of four tints so a message keeps its colour
  /// across refreshes.
  private static func tint(for id: String) -> Color {
    let tints: [Color] = [.lavenderMist, .blushPowder, .skyWash, .peachCloud]
    let index = abs(id.utf8.reduce(0) { ($0 &* 31) &+ Int($1) }) % tints.count
    return tints[index]
  }
}

/// A radial-gradient avatar with a serif italic initial.
private struct PeaceMessageAvatar: View {
  let tint: Color
  let initial: String

  var body: some View {
    ZStack {
      Circle()
        .fill(
          RadialGradient(
            colors: [.white.opacity(0.95), tint.opacity(0.85)],
            center: .topLeading,
            startRadius: 1,
            endRadius: 24
          )
        )
      Text(initial)
        .font(.system(.subheadline, design: .serif, weight: .light))
        .italic()
        .foregroundStyle(Color.deepPlum.opacity(0.85))
    }
    .overlay(
      Circle().stroke(.white.opacity(0.7), lineWidth: 0.6)
    )
    .shadow(color: tint.opacity(0.4), radius: 6, x: 0, y: 3)
  }
}

#Preview("Peace Messages") {
  ScrollView {
    PeaceMessagesSection(messages: FixturePauseEventRepository.sampleMessages)
      .padding(.vertical, 24)
  }
  .background { AtmosphereBackground() }
}
