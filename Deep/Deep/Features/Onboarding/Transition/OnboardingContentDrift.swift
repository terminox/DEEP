import SwiftUI

/// The onboarding hand-off happens in two layers: the coordinator crossfades
/// whole screens (pure opacity, so fixed elements — chrome, footer CTAs — hold
/// perfectly still), while each screen's *content* additionally drifts and
/// softens through a `SoftDriftTransition` with its own fade disabled, so the
/// two layers never compound opacities. The drift direction follows the
/// coordinator's routing (forward rises in from below, back sinks out the way
/// it came), read from the `onboardingNavDirection` environment value.
/// Reduce Motion drops the drift and blur (the transition degrades to
/// identity), leaving just the coordinator's crossfade.
private struct OnboardingContentDrift: ViewModifier {
  @Environment(\.onboardingNavDirection) private var direction

  func body(content: Content) -> some View {
    content.transition(SoftDriftTransition(direction: direction, fades: false))
  }
}

extension View {
  /// Apply to a screen's content block (never its footer CTA) so it drifts
  /// gently into place while the coordinator crossfades screens.
  func onboardingContentDrift() -> some View {
    modifier(OnboardingContentDrift())
  }
}

#Preview("Content drift") {
  @Previewable @State var showsFirst = true

  ZStack {
    // Stand-ins for two onboarding screens — no real dependencies. The footer
    // button stays put; only the content block drifts.
    VStack(spacing: .rhythm) {
      Group {
        if showsFirst {
          LinearGradient(colors: [.peachCloud, .blushPowder], startPoint: .top, endPoint: .bottom)
            .clipShape(RoundedRectangle(cornerRadius: .card, style: .continuous))
            .overlay {
              Text("First screen")
                .font(DeepType.sectionTitle)
                .foregroundStyle(.deepPlum)
            }
            .id("first")
        } else {
          LinearGradient(colors: [.skyWash, .moonCream], startPoint: .top, endPoint: .bottom)
            .clipShape(RoundedRectangle(cornerRadius: .card, style: .continuous))
            .overlay {
              Text("Second screen")
                .font(DeepType.sectionTitle)
                .foregroundStyle(.deepPlum)
            }
            .id("second")
        }
      }
      .onboardingContentDrift()

      Button("Toggle") {
        withAnimation(.hush) { showsFirst.toggle() }
      }
    }
    .padding(.edge)
  }
}
