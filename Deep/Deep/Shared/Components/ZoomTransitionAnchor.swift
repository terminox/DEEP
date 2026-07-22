import SwiftUI
import UIKit

extension View {
  /// Captures the UIKit view laid under this SwiftUI view so a shell-owned
  /// UIKit presentation (`UIViewController.Transition.zoom`) can morph out of
  /// its frame. SwiftUI's own `matchedTransitionSource` cannot reach a
  /// presentation made by a UIKit controller on the far side of the hosting
  /// boundary; this anchor is the bridge. The planted view is invisible,
  /// touch-transparent, and sized to this view's bounds, so the zoom geometry
  /// matches what the user tapped.
  func zoomTransitionAnchor(_ anchor: Binding<UIView?>) -> some View {
    background(ZoomTransitionAnchorReader(anchor: anchor))
  }
}

private struct ZoomTransitionAnchorReader: UIViewRepresentable {
  @Binding var anchor: UIView?

  func makeUIView(context: Context) -> UIView {
    let view = UIView()
    view.backgroundColor = .clear
    view.isUserInteractionEnabled = false
    return view
  }

  func updateUIView(_ view: UIView, context: Context) {
    // Publishing the anchor mutates state, which is illegal mid-update — hop
    // off the update pass first.
    guard anchor !== view else { return }
    Task { @MainActor in anchor = view }
  }
}

#Preview("Zoom transition anchor") {
  @Previewable @State var anchor: UIView?

  Button("Launch") {}
    .padding()
    .zoomTransitionAnchor($anchor)
}
