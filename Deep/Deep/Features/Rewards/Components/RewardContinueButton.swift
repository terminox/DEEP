import SwiftUI

/// The one forward affordance shared by every reward step — and, now, by the
/// paywall. Its label changes at the edge of the ritual, while its shape and
/// placement remain familiar.
///
/// The pill, its shadow and its 56pt height all live *inside* the button's
/// label: that is what makes the whole capsule tappable and what gives
/// `.softPress` a pill to depress rather than just the text glyphs. Matches
/// `OnboardingPrimaryButton`.
struct RewardContinueButton: View {
  private let label: Text
  /// Whether this tap closes the ritual rather than advancing it — the default
  /// accessibility hint reads from this, never from the label.
  private let isFinal: Bool
  /// True while the tap's work is still in flight. The button holds still and
  /// says so, rather than looking live and silently eating taps.
  private let isBusy: Bool
  /// Overrides the reward-flow hint for callers outside that flow.
  private let hint: LocalizedStringKey?
  private let action: () -> Void

  /// For a caller that has already resolved its title — a `String` chosen at
  /// runtime. Note that such a title does *not* pass through the String
  /// Catalog; resolve it yourself if it needs translating.
  init(
    title: String,
    isFinal: Bool = false,
    isBusy: Bool = false,
    accessibilityHint: LocalizedStringKey? = nil,
    action: @escaping () -> Void
  ) {
    self.label = Text(title)
    self.isFinal = isFinal
    self.isBusy = isBusy
    self.hint = accessibilityHint
    self.action = action
  }

  /// For a literal title, which resolves through the String Catalog against the
  /// view's locale — so the in-app language picker reaches it, and a preview
  /// that sets `\.locale` renders the translation.
  init(
    _ titleKey: LocalizedStringKey,
    isFinal: Bool = false,
    isBusy: Bool = false,
    accessibilityHint: LocalizedStringKey? = nil,
    action: @escaping () -> Void
  ) {
    self.label = Text(titleKey)
    self.isFinal = isFinal
    self.isBusy = isBusy
    self.hint = accessibilityHint
    self.action = action
  }

  var body: some View {
    Button(action: action) {
      ZStack {
        label
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
    .accessibilityHint(hint ?? (isFinal
      ? "Closes the session and returns to the app"
      : "Shows the next part of your session rewards"))
  }
}

#Preview {
  VStack(spacing: .rhythm) {
    RewardContinueButton(title: "Continue", action: {})
    RewardContinueButton(title: "Send & continue", isBusy: true, action: {})
    RewardContinueButton(title: "Carry this calm", isFinal: true, action: {})
    RewardContinueButton(
      "Start your 7 days free",
      accessibilityHint: "Starts your free trial of DEEP Premium",
      action: {}
    )
  }
  .padding(.edge)
  .background(.moonCream)
}
