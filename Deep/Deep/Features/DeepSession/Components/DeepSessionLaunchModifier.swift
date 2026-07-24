import SwiftUI

extension View {
  /// Marks this control as the zoom source and presents the full Deep Session
  /// flow (intro → session) over the entire shell — tab bar and mini player
  /// included — when `isPresented` flips. The morph lifts the control's real
  /// rendered content, so entry cards get the Apple-Music-style zoom without
  /// any UIKit bridging.
  func deepSessionLaunch(session: DeepSession, isPresented: Binding<Bool>) -> some View {
    modifier(DeepSessionLaunchModifier(session: session, isPresented: isPresented))
  }
}

private struct DeepSessionLaunchModifier: ViewModifier {
  let session: DeepSession
  @Binding var isPresented: Bool

  /// One namespace per attached control, so every entry card can use the same
  /// source id without colliding.
  @Namespace private var zoom
  private static let sourceID = "deepSessionEntry"

  func body(content: Content) -> some View {
    content
      .matchedTransitionSource(id: Self.sourceID, in: zoom) {
        // The lift clips to the entry cards' frosted-card shape.
        $0.clipShape(.rect(cornerRadius: .card))
      }
      .fullScreenCover(isPresented: $isPresented) {
        DeepSessionCoordinatorView(session: session)
          .navigationTransition(.zoom(sourceID: Self.sourceID, in: zoom))
      }
  }
}

#Preview("Deep session launch") {
  @Previewable @State var isPresented = false

  Button("Launch") { isPresented = true }
    .padding()
    .deepSessionLaunch(session: DeepSessionLibrary.balancingBreath, isPresented: $isPresented)
    .environment(\.soundPlayer, MockSoundPlayer.idle)
}
