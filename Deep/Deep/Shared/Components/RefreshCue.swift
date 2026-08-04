import SwiftUI

/// Custom pull-to-refresh for hero-led screens. A full-bleed `StretchyHero`
/// stays pinned over the exact spot the system refresh spinner lives in — and
/// the system trigger sits deeper than this app wants, so
/// `heroRefreshable(action:)` replaces `.refreshable` outright: it watches the
/// scroll's overscroll directly, arms a small glass cue just below the pinned
/// title block, and fires the moment the pull crosses the threshold while the
/// finger is still down — no deep drag, no release required.
struct RefreshCue: View {
  /// 0…1 fill of the progress ring while the pull is armed.
  var progress: Double
  /// Swaps the ring for the indeterminate spinner once the refresh fires.
  var isSpinning: Bool

  var body: some View {
    ZStack {
      Color.clear
        .frame(width: 44, height: 44)
        .modifier(LiquidGlassCircle())
      // Drawn over — not inside — the glass layer, so the per-frame ring
      // updates during a drag never re-rasterise the glass itself.
      if isSpinning {
        ProgressView()
          .tint(.deepPlum)
          .transition(.opacity)
      } else {
        Circle()
          .trim(from: 0, to: progress)
          .stroke(.deepPlum, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
          .rotationEffect(.degrees(-90))
          .frame(width: 20, height: 20)
          .transition(.opacity)
      }
    }
    .animation(.settle, value: isSpinning)
    .accessibilityLabel("Refreshing")
  }
}

extension View {
  /// Pull-to-refresh for screens led by a stretchy hero: an eager, fully
  /// custom pull (fires at `RefreshMonitor.threshold` points of overscroll
  /// while dragging) with a visible `RefreshCue` the hero can't cover.
  func heroRefreshable(action: @escaping () async -> Void) -> some View {
    modifier(HeroRefreshable(action: action))
  }
}

private struct HeroRefreshable: ViewModifier {
  let action: () async -> Void
  @State private var monitor = RefreshMonitor()

  func body(content: Content) -> some View {
    content
      // Clamped in the transform, so scrolling into the content produces a
      // constant 0 and never invokes the action — the observers only do work
      // during an actual overscroll.
      .onScrollGeometryChange(for: CGFloat.self) { geometry in
        max(0, -(geometry.contentOffset.y + geometry.contentInsets.top))
      } action: { [monitor] _, pull in
        monitor.update(pull: pull, action: action)
      }
      // The trigger is re-evaluated from both callbacks: a pull held
      // perfectly still stops producing geometry changes, and the two
      // updates can land in either order within a frame.
      .onScrollPhaseChange { [monitor] _, newPhase in
        monitor.update(
          touching: newPhase == .interacting || newPhase == .tracking,
          action: action
        )
      }
      // The greedy frame respects the safe area even though the leaf scroll
      // ignores it, so the overlay's top edge is the safe-area top — below the
      // status bar, and below any nav bar the screen sits under — on every
      // screen, no matter how the call site's chain is shaped.
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .overlay(alignment: .top) { RefreshCueHost(monitor: monitor) }
      // `.refreshable` used to provide this for free: VoiceOver users can't
      // rubber-band, so expose the refresh as a named action.
      .accessibilityAction(named: "Refresh") { [monitor] in
        monitor.beginRefresh(action)
      }
  }
}

/// The pull state machine. It lives in its own observable box, read only by
/// `RefreshCueHost` — never by the modifier body above — so the 120 Hz pull
/// writes during a drag invalidate nothing but the small cue view, and the
/// two scroll callbacks share state without ordering assumptions.
@MainActor @Observable
private final class RefreshMonitor {
  enum Phase { case idle, refreshing, finishing }

  private(set) var phase: Phase = .idle
  private(set) var pull: CGFloat = 0
  private(set) var isTouching = false
  @ObservationIgnored private var task: Task<Void, Never>?

  /// Overscroll distance that fires the refresh.
  static let threshold: CGFloat = 52
  /// Dead zone before the cue materialises, so incidental bounce stays clean.
  static let appearance: CGFloat = 14
  /// The pull must return below this before another refresh can arm.
  static let reset: CGFloat = 10

  func update(pull: CGFloat, action: @escaping () async -> Void) {
    self.pull = pull
    maybeTrigger(action)
    maybeSettle()
  }

  func update(touching: Bool, action: @escaping () async -> Void) {
    isTouching = touching
    maybeTrigger(action)
    maybeSettle()
  }

  /// VoiceOver entry point — starts a refresh without the gesture gates.
  func beginRefresh(_ action: @escaping () async -> Void) {
    guard phase == .idle else { return }
    start(action)
  }

  private func maybeTrigger(_ action: @escaping () async -> Void) {
    // Finger-down only: a fling that bounces off the top decelerates through
    // the threshold but must never refresh.
    guard phase == .idle, isTouching, pull >= Self.threshold else { return }
    start(action)
  }

  private func start(_ action: @escaping () async -> Void) {
    phase = .refreshing
    task = Task { [weak self] in
      // Runs even if the action is cancelled mid-flight, so the cue can
      // never wedge in the spinning state.
      defer { self?.finish() }
      // Hold the cue for a beat even when the fetch returns instantly, so
      // the gesture always visibly lands.
      async let beat: Void = Self.minimumBeat()
      await action()
      await beat
    }
  }

  private func finish() {
    // `.finishing` doubles as the re-arm latch: the cue stays up under a
    // still-held finger (a fast refresh shouldn't read as "cancelled"), and
    // re-arming requires returning near rest — no instant double-trigger.
    phase = .finishing
    maybeSettle()
  }

  private func maybeSettle() {
    guard phase == .finishing, pull < Self.reset else { return }
    phase = .idle
  }

  private static func minimumBeat() async {
    try? await Task.sleep(for: .milliseconds(600))
  }
}

private struct RefreshCueHost: View {
  let monitor: RefreshMonitor

  /// Distance below the safe-area top that clears the pinned title block —
  /// the `CollapsibleHomeHeader` large title starts 6pt below it and its
  /// subtitle caption ends near 56pt — so the cue always parks below the
  /// title and subtitle, never over them.
  private static let headerClearance: CGFloat = 64

  /// 0…1 ramp from the appearance dead zone to the trigger threshold; drives
  /// the ring fill and the cue's materialisation, tracking the finger with no
  /// animation of its own.
  private var pullProgress: Double {
    let span = RefreshMonitor.threshold - RefreshMonitor.appearance
    return min(1, max(0, (monitor.pull - RefreshMonitor.appearance) / span))
  }

  private var isVisible: Bool {
    monitor.phase != .idle
      || (monitor.isTouching && monitor.pull > RefreshMonitor.appearance)
  }

  var body: some View {
    // The ZStack is always present so `.sensoryFeedback` observes the phase
    // change; a modifier inserted in the same frame as its trigger flips
    // would treat the new value as its baseline and stay silent.
    ZStack(alignment: .top) {
      if isVisible {
        RefreshCue(progress: pullProgress, isSpinning: monitor.phase != .idle)
          .opacity(monitor.phase == .idle ? pullProgress : 1)
          .scaleEffect(monitor.phase == .idle ? 0.8 + 0.2 * pullProgress : 1)
          .padding(.top, Self.headerClearance)
          // A gentle follow: the cue drifts down with the pull and rides the
          // scroll's own spring back up on release.
          .offset(y: min(monitor.pull, RefreshMonitor.threshold) * 0.15)
          .transition(.opacity.combined(with: .scale(scale: 0.8)))
      }
    }
    .animation(.settle, value: isVisible)
    .sensoryFeedback(trigger: monitor.phase) { _, newPhase in
      newPhase == .refreshing ? .impact(weight: .light, intensity: 0.8) : nil
    }
  }
}

/// The same Liquid Glass recipe as `GlassCloseButton`, minus interactivity.
private struct LiquidGlassCircle: ViewModifier {
  func body(content: Content) -> some View {
    content.glassEffect(.regular, in: Circle())
  }
}

#Preview("Refresh cue — mid-pull") {
  ZStack {
    AtmosphereBackground()
    RefreshCue(progress: 0.6, isSpinning: false)
  }
}

#Preview("Refresh cue — spinning") {
  ZStack {
    Color.moonCream.ignoresSafeArea()
    LinearGradient(
      colors: ArtworkPalette.dusk.colors,
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
    .ignoresSafeArea()
    RefreshCue(progress: 1, isSpinning: true)
  }
}
