import SwiftUI

/// Composition root for the first-run onboarding flow. It owns the route stack
/// (`routes`, empty = welcome screen) and renders the current screen directly,
/// handing off between screens with a calm crossfade instead of a navigation
/// push — screens fade in place, so fixed elements (footer CTAs) never move,
/// while each screen's content block adds its own gentle `RiseInTransition`.
/// Persistent chrome — a frosted back button and, on the quiz / Mind Tree
/// steps, the progress bar — floats above the transitioning content, so only
/// the screen beneath it changes. Leaf screens navigate
/// solely through the injected `@Entry` actions; routing stays in this one
/// place, and going back is a plain stack pop (button or edge swipe),
/// everywhere except the crafting loader.
///
/// Route mutations are animated explicitly with `withAnimation` — never an
/// `.animation(value:)` modifier, which would ignore the ripple's
/// `disablesAnimations` transaction and break the instant switch beneath the
/// freeze-frame.
///
/// Leaving the welcome screen (→ first quiz question, or → log in) gets a
/// bespoke send-off: the destination replaces the welcome screen with
/// animations disabled while a freeze-frame of it ripples away above like
/// disturbed water (`RippleRevealOverlay` + `RippleReveal.metal`), expanding
/// from the tapped point. Reduce Motion falls back to a plain crossfade.
struct OnboardingCoordinatorView: View {
  @Environment(\.onboardingStore) private var store
  @Environment(\.onboardingRemote) private var remote
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// The route stack; empty means the welcome screen is showing.
  @State private var routes: [OnboardingRoute] = []
  /// Server-driven questions + mind trees; starts as the bundled fixtures and
  /// is replaced once the backend copy loads. Screens read it via the
  /// `onboardingConfig` environment value.
  @State private var config: OnboardingConfig = .fixture
  /// Present while the welcome freeze-frame ripples away over the just-shown
  /// destination; nil the rest of the time.
  @State private var ripple: RippleContext?
  /// Guards the async gap between a CTA tap and the ripple committing, so a
  /// double-tap can't advance twice.
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

  private var currentRoute: OnboardingRoute? { routes.last }

  /// Chrome shows on every routed screen except the crafting loader, which is
  /// committing the gathered answers and can't be backed out of.
  private var showsChrome: Bool {
    !routes.isEmpty && currentRoute != .craftingSpace
  }

  /// Progress for the persistent bar: the quiz questions plus the Mind Tree
  /// picker as the final step. Nil on screens that aren't counted steps.
  private var progress: (fraction: Double, label: String)? {
    let total = config.questions.count + 1
    switch currentRoute {
    case .quiz(let index):
      return (Double(index + 1) / Double(total), "\(index + 1) of \(total)")
    case .mindTree:
      return (1.0, "\(total) of \(total)")
    default:
      return nil
    }
  }

  var body: some View {
    ZStack {
      // One persistent atmosphere beneath the hand-off, so the crossfade never
      // dips to a half-transparent background mid-transition. Leaf screens
      // keep their own (identical) atmospheres for hermetic previews.
      AtmosphereBackground()

      screen(for: currentRoute)
        .id(currentRoute)
        .transition(.opacity)

      if showsChrome {
        OnboardingChromeBar(
          progress: progress?.fraction,
          fractionLabel: progress?.label,
          onBack: goBack
        )
        .frame(maxHeight: .infinity, alignment: .top)
        .transition(.opacity)
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
      including: routes.isEmpty ? .all : .subviews
    )
    // Edge-swipe back: the familiar leading-edge pop, without a NavigationStack.
    .simultaneousGesture(
      DragGesture(minimumDistance: 20, coordinateSpace: .local)
        .onEnded { value in
          guard value.startLocation.x < 44, value.translation.width > 80, ripple == nil else { return }
          goBack()
        }
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

  /// Routes every leaf-screen advance. Off the welcome screen it's a calm
  /// drift; off it, the destination is swapped in without animation beneath a
  /// rippling freeze-frame of the welcome screen.
  private func advance(to route: OnboardingRoute) {
    guard routes.isEmpty, !reduceMotion, ripple == nil, !isRipplePending else {
      guard route != currentRoute else { return }
      withAnimation(.drift) {
        if case .logIn = currentRoute, case .quiz = route {
          // Post-login resume: replace the stack so back from the first
          // question returns to welcome, not a stale login form.
          routes = [route]
        } else {
          routes.append(route)
        }
      }
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
        routes.append(route)
        isRipplePending = false
      }
    }
  }

  /// Pops one step. A no-op on the welcome screen and the crafting loader.
  private func goBack() {
    guard !routes.isEmpty, currentRoute != .craftingSpace else { return }
    withAnimation(.drift) { _ = routes.removeLast() }
  }

  @ViewBuilder
  private func screen(for route: OnboardingRoute?) -> some View {
    switch route {
    case nil:
      OnboardingIntroView(videoMode: .live(frameGrabber: videoFrameGrabber))
    case .quiz(let index):
      routed(OnboardingQuizView(index: index))
    case .mindTree:
      routed(MindTreePickerView())
    case .createAccount:
      routed(CreateAccountView())
    case .signUp:
      routed(SignUpView())
    case .logIn:
      routed(LogInView())
    case .craftingSpace:
      CraftingSpaceView()
    }
  }

  /// Insets a routed screen's top safe area by the chrome's height so content
  /// starts below the floating back button / progress bar. Each screen bakes
  /// in its own inset, so differing insets never reflow mid-transition.
  private func routed(_ screen: some View) -> some View {
    screen.safeAreaInset(edge: .top) {
      Color.clear.frame(height: OnboardingChromeBar.height)
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
