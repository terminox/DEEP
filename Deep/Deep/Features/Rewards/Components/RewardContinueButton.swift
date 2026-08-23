import SwiftUI

/// The one forward affordance shared by every reward step. Its label changes
/// at the edge of the ritual, while its shape and placement remain familiar.
struct RewardContinueButton: View {
  let title: String
  /// Whether this tap closes the ritual rather than advancing it — the
  /// accessibility hint reads from this, never from the label.
  var isFinal = false
  let action: () -> Void

  var body: some View {
    Button(title, action: action)
      .font(DeepType.body.weight(.semibold))
      .foregroundStyle(.white)
      .frame(maxWidth: .infinity)
      .frame(minHeight: 56)
      .background {
        Capsule().fill(
          LinearGradient(
            colors: [.lavenderMist, .softLilac],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
      }
      .shadow(color: .lavenderMist.opacity(0.4), radius: 12, x: 0, y: 6)
      .buttonStyle(.softPress)
      .accessibilityHint(isFinal
        ? "Closes the session and returns to the app"
        : "Shows the next part of your session rewards")
  }
}

#Preview {
  VStack(spacing: .rhythm) {
    RewardContinueButton(title: "Continue", action: {})
    RewardContinueButton(title: "Carry this calm", isFinal: true, action: {})
  }
  .padding(.edge)
  .background(.moonCream)
}
