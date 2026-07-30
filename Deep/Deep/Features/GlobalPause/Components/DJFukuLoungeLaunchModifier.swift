import SwiftUI

extension View {
  /// Marks this control as the zoom source and presents Fuku's Lounge over the
  /// entire shell — tab bar and mini player included — when `isPresented`
  /// flips. The morph lifts the control's real rendered content, the same
  /// Apple-Music-style zoom `deepSessionLaunch` uses.
  func djFukuLoungeLaunch(isPresented: Binding<Bool>) -> some View {
    modifier(DJFukuLoungeLaunchModifier(isPresented: isPresented))
  }
}

private struct DJFukuLoungeLaunchModifier: ViewModifier {
  @Binding var isPresented: Bool

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
        DJFukuLoungeView(onClose: { isPresented = false })
          .navigationTransition(.zoom(sourceID: Self.sourceID, in: zoom))
          .preferredColorScheme(.light)
      }
  }
}

#Preview("Fuku's Lounge launch") {
  @Previewable @State var isPresented = false

  Button("Launch") { isPresented = true }
    .padding()
    .djFukuLoungeLaunch(isPresented: $isPresented)
}
