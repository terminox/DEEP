import SwiftUI

/// Composition root for the first-run onboarding flow. It owns the route stack
/// (`routes`, empty = welcome screen) and renders the current screen directly,
/// handing off between screens with a calm `.hush` crossfade instead of a
/// navigation push — screens fade in place, so fixed elements (footer CTAs)
/// never move, while each screen's content block adds its own gentle
/// `.onboardingContentDrift()`, following the routing direction injected via
/// `onboardingNavDirection`.
/// The flow's content — quiz questions and Mind Trees — is server-driven, so
/// the coordinator also owns fetching it and the state that fetch is in. The
/// welcome screen's CTA waits on that state and offers a retry when it fails;
/// nothing falls back to bundled content.
///
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
  /// Where the fetch of the server-driven questions + mind trees has got to.
  /// Screens read the loaded config via the `onboardingConfig` environment
  /// value; there is deliberately no bundled fallback — see `OnboardingConfig`.
  @State private var configLoad: ConfigLoad = .loading
  /// Bumped to re-run the fetch; drives the `.task(id:)` below.
  @State private var configAttempt = 0
  /// A config-dependent route asked for before the config arrived. Only the
  /// post-login resume can get here — every other caller is gated on the
  /// config — and it is replayed the moment the fetch succeeds.
  @State private var pendingRoute: OnboardingRoute?
  /// Present while the welcome freeze-frame ripples away over the just-shown
  /// destination; nil the rest of the time.
  @State private var ripple: RippleContext?
  /// Guards the async gap between a CTA tap and the ripple committing, so a
  /// double-tap can't advance twice.
  @State private var isRipplePending = false
  /// Which way the last route change went; leaf content blocks read it (via
  /// `onboardingNavDirection`) so their drift follows the navigation.
  @State private var navDirection = SoftDriftTransition.Direction.forward
  /// Freezes the welcome video's current frame at tap time.
  @State private var videoFrameGrabber = LoopingVideoFrameGrabber()
  /// Last touch-down point + screen bounds, recorded outside SwiftUI state so
  /// tracking a touch never invalidates the view tree.
  @State private var touchTracker = RippleTouchTracker()

  private struct RippleContext {
    let stillFrame: UIImage?
    let origin: CGPoint
  }

  private enum ConfigLoad: Equatable {
    case loading
    case loaded(OnboardingConfig)
    case failed
  }

  private var currentRoute: OnboardingRoute? { routes.last }

  /// The fetched config, or `.empty` until it lands. Never the fixture: a
  /// silent fixture fallback made an unreachable backend look like a working
  /// one, since the bundled trees share the real ones' ids, names and taglines
  /// and differ only in their artwork.
  private var config: OnboardingConfig {
    if case .loaded(let config) = configLoad { return config }
    return .empty
  }

  private var isConfigLoaded: Bool {
    if case .loaded = configLoad { return true }
    return false
  }

  private var introConfigState: OnboardingIntroView.ConfigState {
    switch configLoad {
    case .loading: return .loading
    case .loaded: return .ready
    case .failed: return .failed
    }
  }

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
      // AppRootView keeps one persistent atmosphere beneath this coordinator,
      // so the crossfade never dips to a half-transparent background
      // mid-transition. Leaf screens keep their own (identical) atmospheres
      // for hermetic previews.
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
    .environment(\.onboardingNavDirection, navDirection)
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
    .task(id: configAttempt) {
      await loadConfig()
    }
    .task {
      // Compile the ripple shader while the welcome screen idles. The first
      // `layerEffect` use otherwise pays the Metal compile synchronously at
      // tap time — seconds-long with a debugger attached.
      let shader = ShaderLibrary.rippleReveal(
        .float2(CGPoint.zero),
        .float2(CGSize(width: 1, height: 1)),
        .float(0),
        .color(.moonCream)
      )
      try? await shader.compile(as: .layerEffect)
    }
  }

  /// Waits between attempts so a cold backend still lands. Production Cloud
  /// Run scales to zero (`infra/config.ts` keeps `minInstances` at 0), and its
  /// first request after an idle spell routinely outlasts `APIClient`'s
  /// deliberately short 10 s request timeout. A single silent attempt used to
  /// leave onboarding showing bundled sample trees for the rest of the run.
  private static let configRetryDelays: [Duration] = [.zero, .seconds(1), .seconds(3)]

  /// Fetches the server-driven config, retrying before giving up. The welcome
  /// screen's CTA follows the resulting state, so a failure is visible and
  /// recoverable instead of being papered over with bundled content.
  private func loadConfig() async {
    configLoad = .loading
    for delay in Self.configRetryDelays {
      if delay > .zero {
        guard (try? await Task.sleep(for: delay)) != nil else { return }
      }
      if let fetched = try? await remote.fetchConfig() {
        configLoad = .loaded(fetched)
        if let pendingRoute {
          self.pendingRoute = nil
          advance(to: pendingRoute)
        }
        return
      }
      // `try?` swallows cancellation too — don't spend the remaining attempts
      // on a view that has gone away.
      if Task.isCancelled { return }
    }
    configLoad = .failed
  }

  /// Re-runs `loadConfig()` by invalidating the `.task(id:)`.
  private func retryConfig() {
    configAttempt += 1
  }

  /// Routes every leaf-screen advance. Off the welcome screen it's a calm
  /// hush; off it, the destination is swapped in without animation beneath a
  /// rippling freeze-frame of the welcome screen.
  private func advance(to route: OnboardingRoute) {
    // The quiz is pure server content, and `OnboardingQuizView` reads its
    // question by index. Hold the route until the config lands rather than
    // pushing an empty flow.
    if case .quiz = route, !isConfigLoaded {
      pendingRoute = route
      if configLoad == .failed { retryConfig() }
      return
    }
    guard routes.isEmpty, !reduceMotion, ripple == nil, !isRipplePending else {
      guard route != currentRoute else { return }
      navDirection = .forward
      withAnimation(.hush) {
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
      // Bounded grab: a stalled decoder must never wedge navigation. On
      // timeout the ripple runs over a nil frame — atmosphere + veils — which
      // still reads correctly (the tap origin sits over the near-solid veil).
      let frame = await withTaskGroup(of: UIImage?.self) { group in
        group.addTask { @MainActor [videoFrameGrabber] in
          await videoFrameGrabber.currentFrame()
        }
        group.addTask {
          try? await Task.sleep(for: .milliseconds(400))
          return nil
        }
        let first = await group.next() ?? nil
        group.cancelAll()
        return first
      }
      guard routes.isEmpty, ripple == nil else {
        isRipplePending = false
        return
      }
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
    navDirection = .backward
    withAnimation(.hush) { _ = routes.removeLast() }
  }

  @ViewBuilder
  private func screen(for route: OnboardingRoute?) -> some View {
    switch route {
    case nil:
      OnboardingIntroView(
        videoMode: .live(frameGrabber: videoFrameGrabber),
        configState: introConfigState,
        onRetry: retryConfig
      )
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

#if DEBUG
#Preview("Onboarding — Full flow") {
  // The host backdrop AppRootView provides in the app, so the preview stays
  // hermetic and true to what ships.
  ZStack {
    Color.moonCream.ignoresSafeArea()
    AtmosphereBackground()
    OnboardingCoordinatorView()
      .environment(\.onboardingStore, MockOnboardingStore.fresh)
  }
}
#endif
