import SwiftUI

/// A home-screen header that floats over a `StretchyHero` and collapses
/// like the iOS large-title nav bar. At rest the title sits large in the
/// top-left over the video (white, legible against the footage); as the scroll
/// rises the large title rolls up and clips out while a compact title rises into
/// a progressively-blurred bar from just below — a directional roll, not a
/// cross-dissolve.
///
/// Apply with `.collapsibleHomeHeader(title:subtitle:trailing:)` to a home
/// screen whose body is a `ScrollView` leading with `StretchyHero` (see
/// `DeepSoundHomeView`, `MindGardenHomeView`). The modifier owns the collapse
/// state and renders the header as an overlay, so it floats over the hero rather
/// than insetting the scroll — keeping the full-bleed hero intact.
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
  /// How far the titles travel vertically as they roll through the bar.
  private let rollTravel: CGFloat = 40

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
    let barHeight = topInset + compactBarHeight
    return ZStack(alignment: .topLeading) {
      // Progressive blur: full at the status bar, dissolving to clear at the
      // bar's lower edge (no hard line). Fades in only as the header collapses.
      VariableBlurView(maxBlurRadius: 20, direction: .blurredTopClearBottom)
        .frame(height: barHeight)
        .opacity(barMaterialOpacity)
        .allowsHitTesting(false)

      // Title roll — the only clipped region, so the large title disappears
      // under the status bar instead of fading in place.
      titleRoll(topInset: topInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: barHeight, alignment: .top)
        .clipped()
        .padding(.horizontal, .edge)
        .allowsHitTesting(false)

      // Subtitle — positioned below the large title, outside the clip, fading
      // out first so the compact bar shows the name only.
      if let subtitle {
        Text(subtitle)
          .font(DeepType.caption)
          .foregroundStyle(.white.opacity(0.92))
          .shadow(color: .deepPlum.opacity(legibilityShadow), radius: 6, y: 1)
          .opacity(1 - smoothstep(0, 0.4, progress))
          .lineLimit(1)
          .padding(.top, topInset + 40)
          .padding(.horizontal, .edge)
          .allowsHitTesting(false)
      }

      // Trailing accessory — fixed top-right, does not roll.
      HStack(spacing: 0) {
        Spacer(minLength: 0)
        trailing
      }
      .padding(.top, topInset + 6)
      .padding(.horizontal, .edge)
    }
    .frame(maxHeight: .infinity, alignment: .top)
    .ignoresSafeArea(edges: .top)
  }

  /// The large title rolls up and out; the compact title rises into its slot
  /// from just below. Both share the top-left origin and the white→plum colour.
  private func titleRoll(topInset: CGFloat) -> some View {
    ZStack(alignment: .topLeading) {
      Text(title)
        .font(DeepType.wordmark)
        .shadow(color: .deepPlum.opacity(legibilityShadow), radius: 8, y: 2)
        .opacity(1 - smoothstep(0.45, 0.9, progress))
        .offset(y: -progress * rollTravel)

      Text(title)
        .font(.system(.title3, design: .serif, weight: .light).italic())
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .opacity(smoothstep(0.5, 0.95, progress))
        .offset(y: (1 - progress) * rollTravel)
    }
    .foregroundStyle(titleColor)
    .padding(.top, topInset + 6)
  }

  // MARK: - Derived values

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
        StretchyHero(media: .video(resource: "sky"), height: 320)
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
