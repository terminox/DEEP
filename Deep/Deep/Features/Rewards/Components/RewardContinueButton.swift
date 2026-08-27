import SwiftUI

/// The one forward affordance shared by every reward step. Its label changes
/// at the edge of the ritual, while its shape and placement remain familiar.
///
/// The pill, its shadow and its 56pt height all live *inside* the button's
/// label: that is what makes the whole capsule tappable and what gives
/// `.softPress` a pill to depress rather than just the text glyphs. Matches
/// `OnboardingPrimaryButton`.
struct RewardContinueButton: View {
  let title: String
  /// Whether this tap closes the ritual rather than advancing it — the
  /// accessibility hint reads from this, never from the label.
  var isFinal = false
  /// True while the tap's work is still in flight. The button holds still and
  /// says so, rather than looking live and silently eating taps.
  var isBusy = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      ZStack {
        Text(title)
          .font(DeepType.body.weight(.semibold))
          .opacity(isBusy ? 0 : 1)
        if isBusy {
          ProgressView()
            .tint(.white)
        }
      }
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
      .opacity(isBusy ? 0.72 : 1)
    }
    .buttonStyle(.softPress)
    .disabled(isBusy)
    .animation(.settle, value: isBusy)
    .accessibilityHint(isFinal
      ? "Closes the session and returns to the app"
      : "Shows the next part of your session rewards")
  }
}

#Preview {
  VStack(spacing: .rhythm) {
    RewardContinueButton(title: "Continue", action: {})
    RewardContinueButton(title: "Send & continue", isBusy: true, action: {})
    RewardContinueButton(title: "Carry this calm", isFinal: true, action: {})
  }
  .padding(.edge)
  .background(.moonCream)
}
