import SwiftUI

struct VoicesOfPeaceSection: View {
  let voices: [VoiceOfPeace]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Voices of peace", trailing: "See all")

      HStack(alignment: .top, spacing: 12) {
        ForEach(voices.prefix(2)) { voice in
          VoiceCard(voice: voice)
            .frame(maxWidth: .infinity)
        }
      }
      .padding(.horizontal, .edge)
    }
  }
}

private struct VoiceCard: View {
  let voice: VoiceOfPeace

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .center, spacing: 8) {
        VoiceAvatar(tint: voice.avatarTint, initial: voice.name.first.map(String.init) ?? "?")
          .frame(width: 32, height: 32)

        VStack(alignment: .leading, spacing: 1) {
          Text(voice.name)
            .font(DeepType.body.weight(.medium))
            .foregroundStyle(.deepPlum)
            .lineLimit(1)
          Text(voice.country)
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
            .lineLimit(1)
        }
      }

      Text("\u{201C}\(voice.quote)\u{201D}")
        .font(DeepType.caption)
        .foregroundStyle(Color.deepPlum.opacity(0.78))
        .lineSpacing(2)
        .fixedSize(horizontal: false, vertical: true)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(14)
    .frostedCard(cornerRadius: 20)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(voice.name) from \(voice.country) says: \(voice.quote)")
  }
}

private struct VoiceAvatar: View {
  let tint: VoiceOfPeace.AvatarTint
  let initial: String

  var body: some View {
    ZStack {
      Circle()
        .fill(
          RadialGradient(
            colors: [.white.opacity(0.95), color.opacity(0.85)],
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
    .shadow(color: color.opacity(0.4), radius: 6, x: 0, y: 3)
  }

  private var color: Color {
    switch tint {
    case .lavender: .lavenderMist
    case .blush:    .blushPowder
    case .sky:      .skyWash
    case .peach:    .peachCloud
    }
  }
}

#Preview {
  VoicesOfPeaceSection(voices: VoiceOfPeace.samples)
    .padding(.vertical)
    .background(.moonCream)
}
