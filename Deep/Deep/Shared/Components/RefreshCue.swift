import SwiftUI

/// The pull-to-refresh cue for hero-led screens. A full-bleed `StretchyHero`
/// grows into the overscroll gap — the exact spot the system refresh spinner
/// lives in — so on those screens the spinner spins invisibly behind the art.
/// `heroRefreshable(action:)` keeps the native pull gesture but floats this
/// small glass chip just below the safe area while the refresh is in flight.
struct RefreshCue: View {
  var body: some View {
    ProgressView()
      .tint(.deepPlum)
      .frame(width: 44, height: 44)
      .modifier(LiquidGlassCircle())
      .accessibilityLabel("Refreshing")
  }
}

extension View {
  /// `.refreshable` for screens whose stretchy hero hides the system spinner:
  /// the same pull gesture, with a visible `RefreshCue` the hero can't cover.
  func heroRefreshable(action: @escaping () async -> Void) -> some View {
    modifier(HeroRefreshable(action: action))
  }
}

private struct HeroRefreshable: ViewModifier {
  let action: () async -> Void
  @State private var monitor = RefreshMonitor()

  func body(content: Content) -> some View {
    content
      .refreshable { [monitor] in
        withAnimation(.settle) { monitor.isRefreshing = true }
        defer { withAnimation(.settle) { monitor.isRefreshing = false } }
        // Hold the cue for a beat even when the fetch returns instantly, so
        // the gesture always visibly lands.
        async let beat: Void = minimumBeat()
        await action()
        await beat
      }
      .overlay(alignment: .top) { RefreshCueHost(monitor: monitor) }
  }

  private func minimumBeat() async {
    try? await Task.sleep(for: .milliseconds(600))
  }
}

/// The in-flight flag lives in its own observable box, read only by
/// `RefreshCueHost` — never by the modifier body above. If the modifier body
/// re-evaluated while a refresh runs, `.refreshable` would be re-applied and
/// the system would cancel the in-flight refresh task on the spot.
@MainActor @Observable
private final class RefreshMonitor {
  var isRefreshing = false
}

private struct RefreshCueHost: View {
  let monitor: RefreshMonitor

  var body: some View {
    if monitor.isRefreshing {
      RefreshCue()
        .padding(.top, 8)
        .transition(.opacity.combined(with: .scale(scale: 0.8)))
    }
  }
}

/// Liquid Glass on iOS 26, hand-blended frosted material on iOS 18–25 —
/// the same recipe as `GlassCloseButton`, minus interactivity.
private struct LiquidGlassCircle: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 26.0, *) {
      content.glassEffect(.regular, in: Circle())
    } else {
      content.background(
        ZStack {
          Circle().fill(.ultraThinMaterial)
          Circle().fill(.white.opacity(0.4))
          Circle().strokeBorder(.white.opacity(0.5), lineWidth: 0.5)
        }
      )
    }
  }
}

#Preview("Refresh cue") {
  ZStack {
    AtmosphereBackground()
    RefreshCue()
  }
}

#Preview("Refresh cue over bright art") {
  ZStack {
    Color.moonCream.ignoresSafeArea()
    LinearGradient(
      colors: ArtworkPalette.dusk.colors,
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
    .ignoresSafeArea()
    RefreshCue()
  }
}
