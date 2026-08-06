import SwiftUI

/// Card / tile artwork that shows a remote photograph beneath the Deep palette
/// gradient. The gradient is kept as a soft branded wash over the image — so
/// photo-backed and gradient-only artwork read as one family — and while the
/// image loads, when there is no URL, or when a load fails, it falls back to the
/// pure gradient treatment, identical to the app's original look.
///
/// Generalises the `CountryImage` pattern so DeepSound and Global Pause render
/// media the same way. `SoundArtwork` is a thin wrapper over it.
struct ArtworkImage: View {
  /// Remote photograph. A `nil`, loading, or failed load shows the gradient alone.
  let url: URL?
  /// Palette stops, top-leading → bottom-trailing — the same colours the
  /// gradient-only artwork used.
  let colors: [Color]
  var cornerRadius: CGFloat = .tile
  /// Optional SF Symbol drawn over the gradient while there is no photo —
  /// the `CountryImage` placeholder look, now available to any artwork.
  var placeholderSystemImage: String? = nil
  /// Optional accent tint drawn bottom-up over the *photo only* (never the
  /// placeholder), inside the component's clip — the `CountryImage` wash.
  var accentWash: Color? = nil
  /// The 0.5pt white edge that gives a tile its lifted, glassy rim. Full-bleed
  /// artwork (a screen-wide hero) must switch this off, or the rim becomes a
  /// hairline drawn straight across the screen.
  var bordered: Bool = true

  @Environment(\.imageLoader) private var imageLoader
  @State private var loaded: UIImage?

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
      .overlay {
        if bordered {
          shape.strokeBorder(.white.opacity(0.35), lineWidth: 0.5)
        }
      }
  }

  @ViewBuilder
  private var content: some View {
    // Probing the memory cache during body means a remounted view (tab switch,
    // lazy-grid recycling) draws its image on the very first pass — no gradient
    // flash and no animation. The bloom cross-fade is reserved for images that
    // genuinely arrive asynchronously, in `load()`.
    let displayed = loaded ?? url.flatMap { imageLoader.cachedImage(for: $0) }
    ZStack {
      if let displayed {
        Image(uiImage: displayed)
          .resizable()
          .scaledToFill()
          .overlay {
            if let accentWash {
              LinearGradient(colors: [.clear, accentWash], startPoint: .top, endPoint: .bottom)
            }
          }
//          .overlay(wash)
//          .overlay(sheen(opacity: 0.25))
      } else {
        gradient
      }
    }
    .task(id: url) { await load() }
    .onChange(of: url) { loaded = nil }
  }

  private func load() async {
    guard let url, loaded == nil else { return }
    // Latch a memory hit into state: the body probe alone would go blank if
    // NSCache ever evicted the entry, with no path back (`.task(id:)` only
    // re-runs on a url change).
    if let cached = imageLoader.cachedImage(for: url) {
      loaded = cached
      return
    }
    guard let image = try? await imageLoader.image(for: url) else { return }
    // The shared download deliberately outlives `.task(id:)` cancellation (it
    // warms the cache) — but a cancelled view must not adopt its result, or a
    // recycled tile would show the previous url's artwork.
    guard !Task.isCancelled else { return }
    withAnimation(.bloom) { loaded = image }
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

  /// Pure gradient treatment — the original `SoundArtwork` look,
  /// shown while loading, offline, or when no image is set.
  private var gradient: some View {
    LinearGradient(
      colors: colors,
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
//    .overlay(sheen(opacity: 0.38))
    .overlay(
      RadialGradient(
        colors: [Color.deepPlum.opacity(0.12), .clear],
        center: .bottomTrailing,
        startRadius: 2,
        endRadius: 240
      )
    )
    .overlay {
      if let placeholderSystemImage {
        Image(systemName: placeholderSystemImage)
          .font(.system(.title2, design: .default, weight: .light))
          .foregroundStyle(.white.opacity(0.55))
      }
    }
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
    // Photo-backed — the fixture loader renders a deterministic gradient
    // image instantly, so previews stay hermetic.
    ArtworkImage(
      url: URL(string: "https://images.unsplash.com/photo-1505144808419-1957a94ca61e?w=600&q=80"),
      colors: [.skyWash, .softLilac]
    )
    .frame(width: 120, height: 120)

    // No URL — the gradient-only fallback, identical to the original look.
    ArtworkImage(url: nil, colors: [.blushPowder, .softLilac])
      .frame(width: 120, height: 120)

    // Delayed fixture — exercises the bloom-in over the gradient placeholder.
    ArtworkImage(
      url: URL(string: "https://images.unsplash.com/photo-1505144808419-1957a94ca61e?w=600&q=80"),
      colors: [.blushPowder, .softLilac],
      placeholderSystemImage: "mountain.2.fill"
    )
    .frame(width: 120, height: 120)
    .environment(\.imageLoader, FixtureImageLoader(delay: .seconds(1)))
  }
  .padding()
  .background(.moonCream)
}
