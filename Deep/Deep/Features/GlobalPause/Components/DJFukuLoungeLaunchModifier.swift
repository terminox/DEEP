import SwiftUI

extension View {
  /// Marks this control as the zoom source and presents Fuku's Lounge over the
  /// entire shell — tab bar and mini player included — when `isPresented`
  /// flips. The morph lifts the control's real rendered content, the same
  /// Apple-Music-style zoom `deepSessionLaunch` uses. Pass the shared Global
  /// Pause `card` for the lounge to borrow while it is open.
  func djFukuLoungeLaunch(
    isPresented: Binding<Bool>,
    card: GlobalPauseCardView? = nil
  ) -> some View {
    modifier(DJFukuLoungeLaunchModifier(isPresented: isPresented, card: card))
  }
}

private struct DJFukuLoungeLaunchModifier: ViewModifier {
  @Binding var isPresented: Bool
  var card: GlobalPauseCardView?

  /// One namespace per attached control, so every entry card can use the same
  /// source id without colliding.
  @Namespace private var zoom
  private static let sourceID = "djFukuLoungeEntry"

  func body(content: Content) -> some View {
    content
      .matchedTransitionSource(id: Self.sourceID, in: zoom) {
        // The lift clips to the entry card's rounded shape.
        $0.clipShape(.rect(cornerRadius: .card))
      }
      .fullScreenCover(isPresented: $isPresented) {
        DJFukuLoungeView(card: card, onClose: { isPresented = false })
          .navigationTransition(.zoom(sourceID: Self.sourceID, in: zoom))
          .preferredColorScheme(.light)
      }
      .onChange(of: isPresented) { _, presented in
        // Hand the borrowed card home as the close begins, so the feed slot is
        // already whole when the zoom-down reveals it. (An interactive dismiss
        // settles through the slot's own window-exit handback.)
        if !presented {
          card?.homeSlot?.handBackCard()
        }
      }
  }
}

#Preview("Fuku's Lounge launch") {
  @Previewable @State var isPresented = false

  Button("Launch") { isPresented = true }
    .padding()
    .djFukuLoungeLaunch(isPresented: $isPresented)
}
