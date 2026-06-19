import SwiftUI

/// The Global Pause card's seat in the Home feed. It draws **nothing** — it just
/// reserves the card's footprint, publishes its live on-screen frame, and turns a
/// tap into the expansion.
///
/// The actual card (atmosphere + live globe + chrome) is a single view owned by
/// `GlobalPauseCoordinatorView`, drawn in an overlay at this slot's frame. Because
/// there is only ever one card instance — never a separate inline copy that the
/// expansion has to hand back to — the collapse lands exactly where it started, with
/// no end-of-transition pop.
struct GlobalPauseHeroSlot: View {
  @Environment(\.openGlobalPause) private var openGlobalPause

  private let cardHeight: CGFloat = 340

  var body: some View {
    Color.clear
      .frame(maxWidth: .infinity)
      .frame(height: cardHeight)
      .contentShape(Rectangle())
      .onTapGesture { openGlobalPause() }
      .background(
        GeometryReader { proxy in
          Color.clear.preference(
            key: HeroCardFramePreferenceKey.self,
            value: proxy.frame(in: .global)
          )
        }
      )
      .padding(.horizontal, .edge)
  }
}

/// Publishes the slot's on-screen (`.global`) frame up to the coordinator, which
/// positions the single hero card there.
struct HeroCardFramePreferenceKey: PreferenceKey {
  static let defaultValue: CGRect = .zero
  static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
    let next = nextValue()
    if next != .zero { value = next }
  }
}

#Preview {
  ZStack {
    AtmosphereBackground()
    GlobalPauseHeroSlot()
  }
}
