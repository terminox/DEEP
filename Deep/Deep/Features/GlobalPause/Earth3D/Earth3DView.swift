import SwiftUI
import simd

/// Standalone Earth3D hero view for Global Pause.
///
/// Self-contained: holds its own EarthRenderer, EarthGlowStore, EarthInteraction,
/// and EarthHaloRipples. The parent only needs to inject (or accept) a glow
/// store to drive country shine.
///
/// Composition (back to front):
///   1. Soft radial bloom backdrop (lavender/cream)
///   2. EarthMetalView (the orb itself + bloom post)
///   3. EarthHaloRipplesOverlay (SwiftUI canvas)
///   4. Tap-reveal country name (serif italic, fades)
struct Earth3DView: View {
  @State private var glow: EarthGlowStore
  @State private var interaction: EarthInteraction
  @State private var ripples = EarthHaloRipples()
  @State private var renderer: EarthRenderer?
  @State private var revealedName: String?
  @State private var revealTask: Task<Void, Never>?

  @MainActor
  init(glow: EarthGlowStore? = nil) {
    _glow = State(initialValue: glow ?? EarthGlowStore())
    _interaction = State(initialValue: EarthInteraction())
  }

  var body: some View {
    GeometryReader { geo in
      // The shader's perspective is fov-Y based, so the orb's screen radius
      // is locked to view *height* (independent of frame aspect). This is
      // what guarantees the orb is never clipped by the frame edges.
      let viewRadius = geo.size.height * CGFloat(EarthRendererConstants.orbScreenRadiusFractionOfHeight)

      ZStack {
        backdrop(side: min(geo.size.width, geo.size.height))

        if let renderer {
          EarthMetalView(renderer: renderer, interaction: interaction)
            .accessibilityLabel("Interactive globe showing where people are pausing")
        }

        EarthHaloRipplesOverlay(
          ripples: ripples,
          orientationProvider: { [interaction] in
            interaction.orientationMatrix(time: Float(CACurrentMediaTime()))
          },
          viewRadius: viewRadius
        )
        .allowsHitTesting(false)

        revealLabel
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
          .padding(.top, 12)
      }
    }
    .onAppear(perform: configureIfNeeded)
  }

  // MARK: - Backdrop (soft halo bowl so the orb feels held, not floating in vacuum)

  @ViewBuilder
  private func backdrop(side: CGFloat) -> some View {
    let bloomRadius = side * 0.55
    ZStack {
      // Upper halo — lavender into transparent.
      Circle()
        .fill(
          RadialGradient(
            colors: [DeepColor.lavenderMist.opacity(0.32), .clear],
            center: .center,
            startRadius: 0,
            endRadius: bloomRadius
          )
        )
        .scaleEffect(1.5)
        .offset(y: -side * 0.04)
      // Lower cradle — blush bowl beneath the orb.
      Ellipse()
        .fill(
          RadialGradient(
            colors: [DeepColor.blushPowder.opacity(0.22), .clear],
            center: .center,
            startRadius: 0,
            endRadius: bloomRadius * 0.6
          )
        )
        .frame(width: side * 0.9, height: side * 0.35)
        .offset(y: side * 0.32)
        .blur(radius: 18)
    }
    .allowsHitTesting(false)
  }

  // MARK: - Tap-reveal country label

  @ViewBuilder
  private var revealLabel: some View {
    if let name = revealedName {
      Text(name)
        .font(.system(.title3, design: .serif, weight: .light).italic())
        .tracking(0.4)
        .foregroundStyle(DeepColor.deepPlum.opacity(0.85))
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(Capsule().fill(.ultraThinMaterial))
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
  }

  // MARK: - Setup

  private func configureIfNeeded() {
    if renderer != nil { return }
    let r = EarthRenderer(glowStore: glow, interaction: interaction)
    r?.onFrame = { time in
      Task { @MainActor in
        glow.tick(time: time)
        ripples.tick(time: time)
      }
    }
    renderer = r
    interaction.onCountryTap = { country in
      revealTask?.cancel()
      withAnimation(DeepMotion.bloom) {
        revealedName = country.name
      }
      revealTask = Task { @MainActor in
        try? await Task.sleep(nanoseconds: 2_400_000_000)
        guard !Task.isCancelled else { return }
        withAnimation(DeepMotion.exhale) {
          revealedName = nil
        }
      }
    }
  }
}

// MARK: - Previews

#Preview("Earth — calm") {
  ZStack {
    AtmosphereBackground()
    Earth3DView(glow: EarthGlowStore.previewCalm)
  }
}

#Preview("Earth — active (live world)") {
  ZStack {
    AtmosphereBackground()
    Earth3DView(glow: EarthGlowStore.previewActive)
  }
}

#Preview("Earth — debug harness") {
  Earth3DDebugHarness()
}
