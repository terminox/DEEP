import SwiftUI

/// The soft full-width pill CTA used to advance through onboarding (the Calm
/// reference's "Next" / "Continue" button, re-cast in Deep's palette).
///
/// When `isEnabled` is false it fades and ignores taps — matching the reference's
/// dimmed "Next" before a choice is made — but never feels like an error.
struct OnboardingPrimaryButton: View {
  let title: String
  var systemImage: String? = nil
  var isEnabled: Bool = true
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        if let systemImage {
          Image(systemName: systemImage)
            .font(DeepType.body.weight(.medium))
        }
        Text(title)
      }
      .font(DeepType.sectionTitle)
      .foregroundStyle(.deepPlum)
      .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
          Capsule(style: .continuous)
            .fill(.moonCream)
            .shadow(color: Color.lavenderMist.opacity(0.35), radius: 20, x: 0, y: 10)
        )
        .overlay(
          Capsule(style: .continuous)
            .strokeBorder(.white.opacity(0.6), lineWidth: 0.5)
        )
    }
    .buttonStyle(.softPress)
    .disabled(!isEnabled)
    .opacity(isEnabled ? 1 : 0.5)
    .animation(.exhale, value: isEnabled)
  }
}

#Preview("Primary button") {
  ZStack {
    AtmosphereBackground()
    VStack(spacing: .rhythm) {
      OnboardingPrimaryButton(title: "Continue", action: {})
      OnboardingPrimaryButton(title: "Continue with Email", systemImage: "envelope", action: {})
      OnboardingPrimaryButton(title: "Next", isEnabled: false, action: {})
    }
    .padding(.horizontal, .edge)
  }
}
