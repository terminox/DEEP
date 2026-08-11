import SwiftUI

/// A gentle "How are you feeling?" prompt — the home's personalization row,
/// mirroring Calm's mood check-in. Tapping is a stubbed CTA.
struct MoodCheckInCard: View {
  var action: () -> Void = {}

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("PERSONALIZE")
        .font(DeepType.micro)
        .tracking(.microTracking)
        .foregroundStyle(.driftGrey)
        .padding(.horizontal, .edge)

      Button(action: action) {
        HStack(spacing: 14) {
          Image(systemName: "face.smiling")
            .font(.system(size: 22, weight: .regular))
            .foregroundStyle(.lavenderMist)
            .frame(width: 44, height: 44)
            .background(.white.opacity(0.6), in: Circle())

          Text("How are you feeling?")
            .font(DeepType.body.weight(.medium))
            .foregroundStyle(.deepPlum)

          Spacer(minLength: 8)

          Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.driftGrey)
        }
        .padding(16)
        .frostedCard()
      }
      .buttonStyle(.softPress)
      .padding(.horizontal, .edge)
    }
  }
}

#Preview("Mood Check-In") {
  ZStack {
    AtmosphereBackground()
    MoodCheckInCard()
  }
}
