import SwiftUI

/// A slim, continuous progress capsule shown at the top of the quiz. Fills from
/// `0` to `1` with the signature slow `.exhale` motion. Mirrors the Calm
/// reference's "1/6" progress affordance, softened to Deep's language (no harsh
/// fraction label by default — progress is reflected, not scored).
struct OnboardingProgressBar: View {
  /// 0...1 fraction complete.
  let progress: Double
  /// Optional "2 of 6" style label. Off by default to keep the screen gentle.
  var fractionLabel: String? = nil

  var body: some View {
    HStack(spacing: 12) {
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Capsule(style: .continuous)
            .fill(Color.softLilac.opacity(0.4))
          Capsule(style: .continuous)
            .fill(.lavenderMist)
            .frame(width: max(0, min(1, progress)) * geo.size.width)
        }
      }
      .frame(height: 6)

      if let fractionLabel {
        Text(fractionLabel)
          .font(DeepType.micro)
          .foregroundStyle(.driftGrey)
          .monospacedDigit()
      }
    }
    .animation(.exhale, value: progress)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Progress")
    .accessibilityValue("\(Int((progress * 100).rounded())) percent")
  }
}

#Preview("Progress bar") {
  ZStack {
    AtmosphereBackground()
    VStack(spacing: .rhythm) {
      OnboardingProgressBar(progress: 0.16)
      OnboardingProgressBar(progress: 0.5, fractionLabel: "3 of 6")
      OnboardingProgressBar(progress: 1.0)
    }
    .padding(.horizontal, .edge)
  }
}
