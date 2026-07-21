import SwiftUI

/// Composition root for the first-run onboarding flow. Like the app's other
/// coordinators it owns a single `NavigationPath`, routes via
/// `.navigationDestination(for:)`, and exposes navigation to its leaf screens
/// through `@Entry` actions — leaf screens never host a `NavigationLink`.
///
/// Styling stays minimal here: each leaf screen draws its own
/// `AtmosphereBackground`, so nothing is hidden behind the `NavigationStack`.
///
/// Leaving the welcome screen (→ first quiz question, or → log in) gets a
/// bespoke send-off: the destination is pushed with animations disabled while
/// a freeze-frame of the welcome screen ripples away above it like disturbed
/// water (`RippleRevealOverlay` + `RippleReveal.metal`), expanding from the
/// tapped point. Reduce Motion falls back to the standard push.
struct OnboardingCoordinatorView: View {
  @Environment(\.onboardingStore) private var store
  @Environment(\.onboardingRemote) private var remote
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var path = NavigationPath()
  /// Server-driven questions + mind trees; starts as the bundled fixtures and
  /// is replaced once the backend copy loads. Screens read it via the
  /// `onboardingConfig` environment value.
  @State private var config: OnboardingConfig = .fixture
  /// Present while the welcome freeze-frame ripples away over the just-pushed
  /// destination; nil the rest of the time.
  @State private var ripple: RippleContext?
  /// Guards the async gap between a CTA tap and the ripple committing, so a
  /// double-tap can't push the same route twice.
  @State private var isRipplePending = false
  /// Freezes the welcome video's current frame at tap time.
  @State private var videoFrameGrabber = LoopingVideoFrameGrabber()
  /// Last touch-down point + screen bounds, recorded outside SwiftUI state so
  /// tracking a touch never invalidates the view tree.
  @State private var touchTracker = RippleTouchTracker()

  private struct RippleContext {
    let stillFrame: UIImage?
    let origin: CGPoint
  }

  var body: some View {
    ZStack {
      NavigationStack(path: $path) {
        OnboardingIntroView(videoMode: .live(frameGrabber: videoFrameGrabber))
          .navigationDestination(for: OnboardingRoute.self) { route in
            destination(for: route)
              // Onboarding is a forward-only ritual — no back button anywhere,
              // and the swipe-back pop is disabled with it. Centralised here so
              // every pushed screen is covered uniformly.
              .navigationBarBackButtonHidden(true)
          }
      }

      if let ripple {
        RippleRevealOverlay(origin: ripple.origin, onFinished: { self.ripple = nil }) {
          OnboardingIntroView(videoMode: .still(frame: ripple.stillFrame))
        }
      }
    }
    .tint(.lavenderMist)
    .environment(\.onboardingConfig, config)
    .environment(\.onboardingAdvance, { route in advance(to: route) })
    .environment(\.onboardingFinish, { store.completeOnboarding() })
    .preferredColorScheme(.light)
    // Only listens while the welcome screen is up, purely to learn where the
    // CTA tap landed so the ripple can emanate from it.
    .simultaneousGesture(
      DragGesture(minimumDistance: 0, coordinateSpace: .global)
        .onChanged { touchTracker.location = $0.startLocation },
      including: path.isEmpty ? .all : .subviews
    )
    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
      touchTracker.bounds = $0
    }
    .task {
      // Best-effort: fall back to the bundled fixtures if the fetch fails.
      if let fetched = try? await remote.fetchConfig() {
        config = fetched
      }
    }
  }

  /// Routes every leaf-screen advance. Off the welcome screen it's a plain
  /// push; off it, the destination is pushed without animation beneath a
  /// rippling freeze-frame of the welcome screen.
  private func advance(to route: OnboardingRoute) {
    guard path.isEmpty, !reduceMotion, ripple == nil, !isRipplePending else {
      path.append(route)
      return
    }
    isRipplePending = true
    let origin = touchTracker.rippleOrigin
    Task { @MainActor in
      let frame = await videoFrameGrabber.currentFrame()
      var transaction = Transaction()
      transaction.disablesAnimations = true
      withTransaction(transaction) {
        ripple = RippleContext(stillFrame: frame, origin: origin)
        path.append(route)
        isRipplePending = false
      }
    }
  }

  @ViewBuilder
  private func destination(for route: OnboardingRoute) -> some View {
    switch route {
    case .quiz(let index): OnboardingQuizView(index: index)
    case .mindTree: MindTreePickerView()
    case .signUp: SignUpView()
    case .logIn: LogInView()
    case .craftingSpace: CraftingSpaceView()
    }
  }
}

/// Reference box the coordinator mutates from gesture callbacks without
/// touching SwiftUI state. Falls back to where the welcome CTAs sit if no
/// touch was recorded (e.g. the advance came from an accessibility action).
@MainActor
final class RippleTouchTracker {
  var location: CGPoint?
  var bounds: CGRect = .zero

  var rippleOrigin: CGPoint {
    location ?? CGPoint(x: bounds.midX, y: bounds.minY + bounds.height * 0.8)
  }
}

#Preview("Onboarding — Full flow") {
  OnboardingCoordinatorView()
    .environment(\.onboardingStore, MockOnboardingStore.fresh)
}
