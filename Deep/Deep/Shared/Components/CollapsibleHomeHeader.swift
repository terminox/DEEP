import SwiftUI

/// A home-screen header that floats over a `StretchyVideoHero` and collapses
/// like the iOS large-title nav bar. At rest the title sits large in the
/// top-left over the video (white, legible against the footage); as the scroll
/// rises it shrinks and settles into a compact, blurred bar pinned at the top
/// (plum on `.regularMaterial`), with its subtitle dropping away first.
///
/// Apply with `.collapsibleHomeHeader(title:subtitle:trailing:)` to a home
/// screen whose body is a `ScrollView` leading with `StretchyVideoHero` (see
/// `DeepSoundHomeView`, `MindGardenHomeView`). The modifier owns the collapse
/// state and renders the header as an overlay, so it floats over the hero
/// rather than insetting the scroll — keeping the full-bleed hero intact.
extension View {
  func collapsibleHomeHeader<Trailing: View>(
    title: String,
    subtitle: String? = nil,
    @ViewBuilder trailing: () -> Trailing = { EmptyView() }
  ) -> some View {
    modifier(
      CollapsibleHomeHeaderModifier(
        title: title,
        subtitle: subtitle,
        trailing: AnyView(trailing())
      )
    )
  }
}

/// True while the header still floats over the dark video (accessories should
/// use their light, over-hero treatment); false once it has settled onto the
/// blurred bar (use the plum treatment). Lets a trailing accessory — e.g. the
/// `HeartBalanceChip` — flip in step with the title without the header needing
/// to know what the accessory is.
extension EnvironmentValues {
  @Entry var headerOverDarkHero: Bool = true
}

private struct CollapsibleHomeHeaderModifier: ViewModifier {
  let title: String
  let subtitle: String?
  let trailing: AnyView

  /// Upward scroll distance, normalised so 0 is the resting top.
  @State private var scrollY: CGFloat = 0

  /// Distance over which the title fully collapses onto the bar. Kept well
  /// below the hero's 220pt fade so the title has settled onto the blur before
  /// the video underneath dissolves.
  private let collapseDistance: CGFloat = 110
  /// Height of the compact bar below the status bar.
  private let compactBarHeight: CGFloat = 52

  /// 0 = expanded large title, 1 = fully collapsed compact bar.
  private var progress: CGFloat {
    min(1, max(0, scrollY / collapseDistance))
  }

  func body(content: Content) -> some View {
    // The leaf scroll ignores the top safe area, so an overlay attached to it
    // reports a zero top inset. Reading the inset from this outer reader —
    // which is not told to ignore it — gives the true status-bar height.
    GeometryReader { proxy in
      let topInset = proxy.safeAreaInsets.top
      content
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
          geometry.contentOffset.y + geometry.contentInsets.top
        } action: { _, newValue in
          scrollY = newValue
        }
        .overlay(alignment: .top) {
          headerBar(topInset: topInset)
        }
        .environment(\.headerOverDarkHero, progress < 0.5)
    }
  }

  private func headerBar(topInset: CGFloat) -> some View {
    ZStack(alignment: .top) {
      Rectangle()
        .fill(.regularMaterial)
        .opacity(barMaterialOpacity)
        .overlay(alignment: .bottom) {
          Divider().opacity(barMaterialOpacity)
        }
        .frame(height: topInset + compactBarHeight)
        .allowsHitTesting(false)

      VStack(alignment: .leading, spacing: 2) {
        HStack(alignment: .center, spacing: 12) {
          titleStack
          Spacer(minLength: 12)
          trailing
        }
        if let subtitle {
          Text(subtitle)
            .font(DeepType.caption)
            .foregroundStyle(.white.opacity(0.92))
            .shadow(color: .deepPlum.opacity(legibilityShadow), radius: 6, y: 1)
            .opacity(1 - smoothstep(0, 0.4, progress))
            .lineLimit(1)
            .allowsHitTesting(false)
        }
      }
      .padding(.horizontal, .edge)
      .padding(.top, topInset + 6)
    }
    .frame(maxHeight: .infinity, alignment: .top)
    .ignoresSafeArea(edges: .top)
  }

  /// The large and compact titles share a top-left origin and cross-fade, so
  /// the title reads as shrinking in place into the bar.
  private var titleStack: some View {
    ZStack(alignment: .topLeading) {
      Text(title)
        .font(DeepType.wordmark)
        .scaleEffect(1 - 0.18 * progress, anchor: .topLeading)
        .shadow(color: .deepPlum.opacity(legibilityShadow), radius: 8, y: 2)
        .opacity(1 - smoothstep(0.55, 1, progress))

      Text(title)
        .font(.system(.title3, design: .serif, weight: .light).italic())
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .opacity(smoothstep(0.6, 1, progress))
    }
    .foregroundStyle(titleColor)
    .allowsHitTesting(false)
  }

  /// White over the video, easing to plum as it lands on the blurred bar.
  private var titleColor: Color {
    Color.white.mix(with: Color.deepPlum, by: progress)
  }

  /// The blur fades in over the back half of the collapse, trailing the compact
  /// title so the bar never appears before the title that belongs on it.
  private var barMaterialOpacity: CGFloat {
    smoothstep(0.5, 1, progress)
  }

  /// Drop-shadow strength for legibility over the video, gone by the midpoint
  /// where the title has moved onto the opaque-enough blur.
  private var legibilityShadow: CGFloat {
    0.35 * (1 - min(1, progress / 0.5))
  }
}

/// Smooth Hermite ease between two edges, clamped to 0...1.
private func smoothstep(_ edge0: CGFloat, _ edge1: CGFloat, _ x: CGFloat) -> CGFloat {
  let t = min(1, max(0, (x - edge0) / (edge1 - edge0)))
  return t * t * (3 - 2 * t)
}

// MARK: - Previews

/// A hermetic skeleton matching the home-screen shape so the canvas exercises
/// both the expanded and collapsed states by scrolling.
private struct CollapsibleHomeHeaderPreview<Trailing: View>: View {
  var title: String
  var subtitle: String
  @ViewBuilder var trailing: () -> Trailing

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        StretchyVideoHero(resource: "sky", height: 320)
        VStack(spacing: .rhythm) {
          ForEach(0..<8, id: \.self) { _ in
            RoundedRectangle(cornerRadius: .card, style: .continuous)
              .fill(.white.opacity(0.6))
              .frame(height: 120)
              .padding(.horizontal, .edge)
          }
        }
        .padding(.top, -80)
      }
    }
    .scrollIndicators(.hidden)
    .ignoresSafeArea(edges: .top)
    .background { AtmosphereBackground() }
    .collapsibleHomeHeader(title: title, subtitle: subtitle, trailing: trailing)
  }
}

#Preview("Collapsible header — over hero") {
  CollapsibleHomeHeaderPreview(
    title: "Deep Sound",
    subtitle: "Sound to settle into"
  ) { EmptyView() }
}

#Preview("Collapsible header — with accessory") {
  CollapsibleHomeHeaderPreview(
    title: "Compassion",
    subtitle: "Where your hearts go"
  ) {
    HeartBalanceChip(balance: 2_450, overDarkHero: true)
  }
}
