import SwiftUI

/// Composition root for the Global Pause tab. Owns the navigation path and the
/// Global Pause hero expansion. Styling lives in the leaf screens (see CLAUDE.md).
///
/// The hero is a **single** card view (atmosphere + live globe + chrome) drawn in an
/// overlay at the feed slot's live frame. `GlobalPauseHeroSlot` in the feed is an
/// empty placeholder that publishes that frame and taps to expand. Because the card
/// is one instance the whole time — collapsed, expanding, full-screen, collapsing —
/// the close lands exactly back on the feed with nothing to swap and nothing to pop.
struct GlobalPauseCoordinatorView: View {
  @State private var player: any SoundPlaying
  @State private var path = NavigationPath()
  @State private var earthGlow = EarthGlowStore()
  @State private var heroExpanded = false
  /// Live frame of the feed slot (`.global`), so the collapsed card tracks the feed.
  @State private var heroCardFrame: CGRect = .zero

  private let tabBarInset: CGFloat = 100
  /// Top strip (status bar + `HomeTopBar`) the collapsed card must slide under, not
  /// over, as it scrolls up the feed.
  private let topBarClearance: CGFloat = 56

  init(soundPlayer: any SoundPlaying = SoundPlayer()) {
    _player = State(initialValue: soundPlayer)
  }

  var body: some View {
    GeometryReader { rootGeo in
      let safeTop = rootGeo.safeAreaInsets.top

      ZStack {
        NavigationStack(path: $path) {
          // The mini player rides in the tab bar's bottom accessory, which
          // participates in the safe area — no extra playing-state inset needed.
          GlobalPauseHomeView(bottomInset: tabBarInset)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: HomeItem.self) { item in
              HomeItemDetailView(item: item)
                .toolbar(.hidden, for: .navigationBar)
            }
        }
        .allowsHitTesting(!heroExpanded)

        // The feed recedes behind the lifting card (App Store feel).
        Color.deepPlum
          .opacity(heroExpanded ? 0.18 : 0)
          .ignoresSafeArea()
          .allowsHitTesting(false)

        heroOverlay(safeTop: safeTop)
      }
      .onPreferenceChange(HeroCardFramePreferenceKey.self) { heroCardFrame = $0 }
    }
    .environment(\.openHomeItem) { item in path.append(item) }
    .environment(\.openGlobalPause, openGlobalPause)
    // Leaf play buttons drive the same shared player that feeds the shell's
    // bottom-accessory mini player — identical to the Sounds tab.
    .environment(\.soundPlayer, player)
    .preferredColorScheme(.light)
  }

  // MARK: - Hero expansion

  private func openGlobalPause() {
    guard heroCardFrame != .zero else { return }
    // Lively spring; any overshoot happens past the screen edge (clipped).
    withAnimation(.spring(response: 0.46, dampingFraction: 0.82)) { heroExpanded = true }
  }

  private func closeHero() {
    // Critically damped (no overshoot) so the card eases exactly back onto the feed.
    withAnimation(.spring(response: 0.45, dampingFraction: 1.0)) { heroExpanded = false }
  }

  /// Quick fade-out on open so the chrome doesn't travel; delayed fade-in on close so
  /// it reappears only as the card settles, matching the feed card.
  private var chromeAnimation: Animation {
    heroExpanded ? .easeOut(duration: 0.18) : .easeOut(duration: 0.20).delay(0.26)
  }

  @ViewBuilder
  private func heroOverlay(safeTop: CGFloat) -> some View {
    GeometryReader { fullGeo in
      // This reader ignores the safe area, so its local origin == `.global` origin
      // and the screen rect is the full bleed.
      let screen = CGRect(origin: .zero, size: fullGeo.size)

      if heroCardFrame != .zero {
        let frame = heroExpanded ? screen : heroCardFrame
        let cornerRadius: CGFloat = heroExpanded ? 0 : .card

        ZStack(alignment: .topLeading) {
          heroCard(cornerRadius: cornerRadius)
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
        }
        .frame(width: fullGeo.size.width, height: fullGeo.size.height, alignment: .topLeading)
        // Collapsed: hide the strip under the top bar so the card slips beneath it
        // while scrolling. The band recedes to 0 as it expands.
        .mask(alignment: .top) {
          VStack(spacing: 0) {
            Color.clear.frame(height: heroExpanded ? 0 : safeTop + topBarClearance)
            Rectangle()
          }
        }
        .overlay(alignment: .topLeading) {
          if heroExpanded {
            GlassCloseButton(action: closeHero)
              .padding(.leading, .edge)
              .padding(.top, safeTop + 8)
              .transition(.opacity)
          }
        }
        // Collapsed: transparent to touches so the feed slot beneath gets taps and
        // scroll. Expanded: the globe rotates and the close button works.
        .allowsHitTesting(heroExpanded)
      }
    }
    .ignoresSafeArea()
  }

  private func heroCard(cornerRadius: CGFloat) -> some View {
    ZStack {
      CardAtmosphere()

      Earth3DView(glow: earthGlow)
        .allowsHitTesting(heroExpanded)

      GlobalPauseCardChrome(caption: "Breathe with the world, together")
        .opacity(heroExpanded ? 0 : 1)
        .offset(y: heroExpanded ? 14 : 0)
        .animation(chromeAnimation, value: heroExpanded)
    }
    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .strokeBorder(.white.opacity(heroExpanded ? 0 : 0.45), lineWidth: 0.5)
    )
    .shadow(
      color: Color.lavenderMist.opacity(heroExpanded ? 0 : 0.25),
      radius: heroExpanded ? 0 : 24,
      x: 0,
      y: heroExpanded ? 0 : 12
    )
  }
}

extension EnvironmentValues {
  /// Routes a tapped home item to the coordinator's navigation path. No-op default.
  @Entry var openHomeItem: (HomeItem) -> Void = { _ in }

  /// Expands the Global Pause hero card. No-op default so the slot previews cleanly.
  @Entry var openGlobalPause: () -> Void = {}
}

#Preview("Global Pause Coordinator") {
  GlobalPauseCoordinatorView(soundPlayer: MockSoundPlayer.idle)
}

#Preview("Global Pause — Playing") {
  GlobalPauseCoordinatorView(soundPlayer: MockSoundPlayer.playing)
}
