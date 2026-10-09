#if DEBUG
import SwiftUI

/// THROWAWAY. A variant is an id, a label and a factory, so each variant file
/// is free to throw out the whole layout.
struct NowPlayingLabVariant: Identifiable {
  let id: String
  let label: String
  /// Whether the variant puts light content over a photograph at the top of
  /// the screen, and so wants a light status bar.
  let lightStatusBar: Bool
  let make: @MainActor (_ onDismiss: @escaping () -> Void) -> AnyView
}

/// THROWAWAY. The registry. Add a variant: one new file, one new line here.
enum NowPlayingLabCatalog {
  static let all: [NowPlayingLabVariant] = [
    NowPlayingLabVariant(id: "canvas", label: "A · Canvas", lightStatusBar: true) {
      AnyView(CanvasNowPlaying(onDismiss: $0))
    },
    NowPlayingLabVariant(id: "canvas-blur", label: "A2 · Canvas + blur", lightStatusBar: true) {
      AnyView(CanvasNowPlaying(onDismiss: $0, blurred: true))
    },
    NowPlayingLabVariant(id: "postcard", label: "B · Postcard", lightStatusBar: true) {
      AnyView(PostcardNowPlaying(onDismiss: $0))
    },
    NowPlayingLabVariant(id: "inset", label: "C · Inset card", lightStatusBar: false) {
      AnyView(InsetCardNowPlaying(onDismiss: $0))
    },
    NowPlayingLabVariant(id: "sky", label: "D · Sky title", lightStatusBar: true) {
      AnyView(SkyTitleNowPlaying(onDismiss: $0))
    },
    NowPlayingLabVariant(id: "current", label: "Current (baseline)", lightStatusBar: false) {
      AnyView(NowPlayingView(onDismiss: $0))
    }
  ]

  /// A2 — the look picked on 2026-10-09; the rest stay one dial away.
  static var defaultID: String { "canvas-blur" }

  static func variant(id: String) -> NowPlayingLabVariant {
    all.first { $0.id == id } ?? all[0]
  }
}
#endif
