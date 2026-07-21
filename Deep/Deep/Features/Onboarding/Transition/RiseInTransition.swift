import SwiftUI

/// The onboarding hand-off happens in two layers: the coordinator crossfades
/// whole screens (pure opacity, so fixed elements — chrome, footer CTAs — hold
/// perfectly still), while each screen's *content* additionally rises a
/// breath into place with this transition. On removal it does nothing, so
/// outgoing content simply fades where it stands and nothing ever jumps.
struct RiseInTransition: Transition {
  func body(content: Content, phase: TransitionPhase) -> some View {
    content.offset(y: phase == .willAppear ? 12 : 0)
  }
}

/// Marks the drifting portion of an onboarding screen — everything above the
/// fixed footer CTA. Respects Reduce Motion by dropping the rise and leaving
/// just the coordinator's crossfade.
private struct OnboardingContentRise: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func body(content: Content) -> some View {
    content.transition(
      reduceMotion ? AnyTransition.identity : AnyTransition(RiseInTransition())
    )
  }
}

extension View {
  /// Apply to a screen's content block (never its footer CTA) so it rises
  /// gently into place while the coordinator crossfades screens.
  func onboardingContentRise() -> some View {
    modifier(OnboardingContentRise())
  }
}

#Preview("Rise in") {
  @Previewable @State var showsFirst = true

  ZStack {
    // Stand-ins for two onboarding screens — no real dependencies. The footer
    // button stays put; only the content block rises.
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
      .onboardingContentRise()

      Button("Toggle") {
        withAnimation(.drift) { showsFirst.toggle() }
      }
    }
    .padding(.edge)
  }
}
