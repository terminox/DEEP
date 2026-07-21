import SwiftUI

/// Persistent onboarding chrome the coordinator floats above the transitioning
/// screens: a frosted back button plus — on the quiz and Mind Tree steps — the
/// shared progress bar. Because it sits outside the drifting content, the bar
/// holds perfectly still while screens hand off beneath it; only its fill
/// glides as progress changes.
struct OnboardingChromeBar: View {
  /// 0...1 fill for the progress capsule; `nil` hides the bar (auth screens
  /// show only the back button).
  var progress: Double?
  /// Optional "1 of 3" style label next to the bar.
  var fractionLabel: String?
  let onBack: () -> Void

  /// Fixed row height. Screens shown under the chrome inset their top safe
  /// area by this much so content never slides beneath the button.
  static let height: CGFloat = 44

  var body: some View {
    HStack(spacing: 12) {
      Button(action: onBack) {
        Image(systemName: "chevron.backward")
          .font(DeepType.sectionTitle)
          .foregroundStyle(.deepPlum)
          .frame(width: 40, height: 40)
          .background(FrostedCardBackground(cornerRadius: .chip))
          .contentShape(Circle())
      }
      .buttonStyle(.softPress)
      .accessibilityLabel("Back")

      if let progress {
        OnboardingProgressBar(progress: progress, fractionLabel: fractionLabel)
      } else {
        Spacer()
      }
    }
    .frame(height: Self.height)
    .padding(.horizontal, .edge)
  }
}

#Preview("Chrome — quiz step") {
  ZStack {
    AtmosphereBackground()
    OnboardingChromeBar(progress: 1.0 / 3.0, fractionLabel: "1 of 3", onBack: {})
  }
}

#Preview("Chrome — back only") {
  ZStack {
    AtmosphereBackground()
    OnboardingChromeBar(onBack: {})
  }
}
