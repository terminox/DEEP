import SwiftUI

/// A freeze-frame of the outgoing screen that dissolves away as an expanding
/// Metal water ripple (`RippleReveal.metal`), revealing whatever is already on
/// screen beneath it. The onboarding coordinator floats one of these above its
/// `NavigationStack` while the destination is pushed underneath without
/// animation — the ripple *is* the transition.
///
/// Purely decorative: hit-testing is disabled from the first frame so the
/// revealed screen is immediately interactive, and `onFinished` fires once the
/// wave has cleared the screen so the owner can drop the overlay.
struct RippleRevealOverlay<Content: View>: View {
  /// Wave epicentre in global (screen) coordinates — the tapped point.
  let origin: CGPoint
  let onFinished: () -> Void
  @ViewBuilder var content: Content

  @State private var progress: Double = 0

  var body: some View {
    content
      .modifier(RippleRevealEffect(progress: progress, origin: origin))
      .allowsHitTesting(false)
      .onAppear {
        withAnimation(.ripple) {
          progress = 1
        } completion: {
          onFinished()
        }
      }
  }
}

/// Animatable bridge that feeds the eased `progress` into the `rippleReveal`
/// layer shader every frame, converting the global tap point into the layer's
/// local space.
private struct RippleRevealEffect: ViewModifier, Animatable {
  var progress: Double
  var origin: CGPoint

  var animatableData: Double {
    get { progress }
    set { progress = newValue }
  }

  func body(content: Content) -> some View {
    content.visualEffect { [progress, origin] view, proxy in
      let frame = proxy.frame(in: .global)
      return view.layerEffect(
        ShaderLibrary.rippleReveal(
          .float2(CGPoint(x: origin.x - frame.minX, y: origin.y - frame.minY)),
          .float2(proxy.size),
          .float(progress),
          .color(.moonCream)
        ),
        maxSampleOffset: CGSize(width: 10, height: 10)
      )
    }
  }
}

#if DEBUG
#Preview("Ripple reveal") {
  @Previewable @State var replay = 0

  ZStack {
    // Stand-ins for the incoming and outgoing screens — no real dependencies.
    LinearGradient(colors: [.skyWash, .moonCream], startPoint: .top, endPoint: .bottom)
      .ignoresSafeArea()
      .overlay {
        Text("Revealed screen")
          .font(DeepType.sectionTitle)
          .foregroundStyle(.deepPlum)
      }

    RippleRevealOverlay(origin: CGPoint(x: 196, y: 700), onFinished: {}) {
      ZStack {
        LinearGradient(colors: [.peachCloud, .blushPowder], startPoint: .top, endPoint: .bottom)
          .ignoresSafeArea()
        Text("Outgoing screen")
          .font(DeepType.sectionTitle)
          .foregroundStyle(.deepPlum)
      }
    }
    .id(replay)

    VStack {
      Spacer()
      Button("Replay") { replay += 1 }
        .padding(.bottom, .rhythm)
    }
  }
}
#endif
