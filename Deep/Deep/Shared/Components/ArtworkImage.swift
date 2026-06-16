import SwiftUI

/// Card / tile artwork that shows a remote photograph beneath the Deep palette
/// gradient. The gradient is kept as a soft branded wash over the image — so
/// photo-backed and gradient-only artwork read as one family — and while the
/// image loads, when there is no URL, or when a load fails, it falls back to the
/// pure gradient treatment, identical to the app's original look.
///
/// Generalises the `CountryImage` pattern so DeepSound and Global Pause render
/// media the same way. `SoundArtwork` and `HomeArtwork` are thin wrappers over it.
struct ArtworkImage: View {
  /// Remote photograph. A `nil`, loading, or failed load shows the gradient alone.
  let url: URL?
  /// Palette stops, top-leading → bottom-trailing — the same colours the
  /// gradient-only artwork used.
  let colors: [Color]
  var cornerRadius: CGFloat = .tile

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    // `Color.clear` adopts exactly the size the caller's `.frame(...)` proposes,
    // fixing the card's layout size *before* the photo is drawn. The image fills
    // that box as an overlay — overlays never grow the layout — so a
    // `.scaledToFill()` photo can overflow only visually, and `clipShape` trims
    // it to the rounded rect. Clipping the image directly (before the frame
    // constrains it) let the enlarged photo bleed past the card.
    Color.clear
      .overlay { content }
      .clipShape(shape)
      .overlay(shape.strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
  }

  @ViewBuilder
  private var content: some View {
    AsyncImage(url: url, transaction: Transaction(animation: .bloom)) { phase in
      switch phase {
      case .success(let image):
        image
          .resizable()
          .scaledToFill()
          .overlay(wash)
          .overlay(sheen(opacity: 0.25))
      default:
        gradient
      }
    }
  }

  /// The branded gradient kept as a translucent wash over the photo. Heavy
  /// enough that the artwork stays unmistakably on-brand while the photograph
  /// still reads as texture beneath it.
  private var wash: some View {
    LinearGradient(
      colors: colors,
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
    .opacity(0.6)
  }

  /// Pure gradient treatment — the original `SoundArtwork` / `HomeArtwork` look,
  /// shown while loading, offline, or when no image is set.
  private var gradient: some View {
    LinearGradient(
      colors: colors,
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
    .overlay(sheen(opacity: 0.38))
    .overlay(
      RadialGradient(
        colors: [Color.deepPlum.opacity(0.12), .clear],
        center: .bottomTrailing,
        startRadius: 2,
        endRadius: 240
      )
    )
  }

  /// Soft top-left highlight that gives the artwork its orb-like dimension.
  private func sheen(opacity: Double) -> some View {
    RadialGradient(
      colors: [.white.opacity(opacity), .white.opacity(0)],
      center: .topLeading,
      startRadius: 2,
      endRadius: 240
    )
  }
}

#Preview("Artwork Image") {
  HStack(spacing: 16) {
    // Photo-backed (loads over the network, blooms in over the gradient).
    ArtworkImage(
      url: URL(string: "https://images.unsplash.com/photo-1505144808419-1957a94ca61e?w=600&q=80"),
      colors: [.skyWash, .softLilac]
    )
    .frame(width: 120, height: 120)

    // No URL — the gradient-only fallback, identical to the original look.
    ArtworkImage(url: nil, colors: [.blushPowder, .softLilac])
      .frame(width: 120, height: 120)
  }
  .padding()
  .background(.moonCream)
}
