import SwiftUI

struct VoicesOfPeaceSection: View {
    let voices: [VoiceOfPeace]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Voices of peace", trailing: "See all")

            VStack(spacing: 12) {
                ForEach(voices.prefix(2)) { voice in
                    VoiceRow(voice: voice)
                }
            }
            .padding(.horizontal, DeepSpacing.edge)
        }
    }
}

private struct VoiceRow: View {
    let voice: VoiceOfPeace

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VoiceAvatar(tint: voice.avatarTint, initial: voice.name.first.map(String.init) ?? "?")
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(voice.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DeepColor.deepPlum)
                    Text(voice.country)
                        .font(.system(size: 11))
                        .foregroundStyle(DeepColor.driftGrey)
                }
                Text("“\(voice.quote)”")
                    .font(.system(size: 12))
                    .foregroundStyle(DeepColor.deepPlum.opacity(0.78))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "quote.bubble")
                .font(.system(size: 12))
                .foregroundStyle(DeepColor.lavenderMist.opacity(0.55))
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
                        endRadius: 28
                    )
                )
            Text(initial)
                .font(.system(size: 16, weight: .light, design: .serif))
                .italic()
                .foregroundStyle(DeepColor.deepPlum.opacity(0.85))
        }
        .overlay(
            Circle().stroke(.white.opacity(0.7), lineWidth: 0.6)
        )
        .shadow(color: color.opacity(0.4), radius: 6, x: 0, y: 3)
    }

    private var color: Color {
        switch tint {
        case .lavender: DeepColor.lavenderMist
        case .blush:    DeepColor.blushPowder
        case .sky:      DeepColor.skyWash
        case .peach:    DeepColor.peachCloud
        }
    }
}

#Preview {
    VoicesOfPeaceSection(voices: VoiceOfPeace.samples)
        .padding(.vertical)
        .background(DeepColor.moonCream)
}
