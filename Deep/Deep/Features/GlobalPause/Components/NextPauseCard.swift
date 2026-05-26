import SwiftUI

struct NextPauseCard: View {
  let target: Date
  let scheduleLines: [String]
  let durationDescription: String
  @Binding var hasJoined: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .center, spacing: 12) {
        GlobeOrb()
          .frame(width: 44, height: 44)
          .accessibilityHidden(true)

        Text("Next Global Pause")
          .font(DeepType.sectionTitle)
          .foregroundStyle(DeepColor.deepPlum)
          .lineLimit(1)
          .minimumScaleFactor(0.8)

        Spacer(minLength: 8)

        CountdownView(target: target)
          .layoutPriority(1)
      }

      HStack(alignment: .bottom, spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          ForEach(scheduleLines, id: \.self) { line in
            Text(line)
              .font(DeepType.caption)
              .foregroundStyle(DeepColor.driftGrey)
          }
          Text(durationDescription)
            .font(DeepType.caption.weight(.medium))
            .foregroundStyle(DeepColor.deepPlum.opacity(0.85))
            .padding(.top, 2)
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 6) {
          joinButton
          Text("You will be notified once we begin")
            .font(.system(.caption2, design: .default))
            .foregroundStyle(DeepColor.driftGrey)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 140, alignment: .trailing)
        }
      }
    }
    .padding(18)
    .frostedCard()
  }

  private var joinButton: some View {
    Button {
      withAnimation(DeepMotion.settle) { hasJoined.toggle() }
    } label: {
      HStack(spacing: 6) {
        Image(systemName: hasJoined ? "checkmark" : "heart.fill")
          .font(.system(.footnote, design: .rounded, weight: .semibold))
        Text(hasJoined ? "Joined" : "I'll join")
          .font(DeepType.body.weight(.medium))
      }
      .foregroundStyle(.white)
      .padding(.horizontal, 18)
      .padding(.vertical, 10)
      .background(
        Capsule().fill(
          LinearGradient(
            colors: [DeepColor.lavenderMist, DeepColor.blushPowder],
            startPoint: .leading,
            endPoint: .trailing
          )
        )
      )
      .shadow(color: DeepColor.lavenderMist.opacity(0.4), radius: 10, x: 0, y: 5)
    }
    .buttonStyle(.softPress)
    .accessibilityLabel(hasJoined ? "You have joined the next global pause" : "Join the next global pause")
  }
}

private struct GlobeOrb: View {
  var body: some View {
    ZStack {
      Circle()
        .fill(
          RadialGradient(
            colors: [.white.opacity(0.9), DeepColor.softLilac.opacity(0.55), DeepColor.lavenderMist.opacity(0.7)],
            center: .topLeading,
            startRadius: 2,
            endRadius: 52
          )
        )
      Image(systemName: "globe.europe.africa.fill")
        .font(.system(size: 22, weight: .regular))
        .foregroundStyle(
          LinearGradient(colors: [DeepColor.lavenderMist, DeepColor.blushPowder], startPoint: .top, endPoint: .bottom)
        )
        .opacity(0.85)
    }
    .overlay(
      Circle().stroke(.white.opacity(0.6), lineWidth: 0.6)
    )
    .shadow(color: DeepColor.lavenderMist.opacity(0.35), radius: 8, x: 0, y: 4)
  }
}

#Preview {
  NextPauseCardPreview()
}

private struct NextPauseCardPreview: View {
  @State private var joined = false
  var body: some View {
    let seconds: TimeInterval = 3600 + 18 * 60 + 42
    NextPauseCard(
      target: Date().addingTimeInterval(seconds),
      scheduleLines: ["Every day, at the same time.", "21:00 Thailand Time"],
      durationDescription: "10 minutes together",
      hasJoined: $joined
    )
    .padding()
    .background(DeepColor.moonCream)
  }
}
