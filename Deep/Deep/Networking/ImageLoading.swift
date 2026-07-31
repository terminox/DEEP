import SwiftUI
import UIKit

/// Source of decoded artwork images. `ArtworkImage` resolves everything it
/// renders through this seam: a synchronous memory probe first (so remounts
/// paint instantly, with no placeholder flash), then the async path which
/// falls through disk and network.
protocol ImageLoading: Sendable {
  /// Instant, memory-only lookup. Non-nil means the image can be drawn on the
  /// current body pass without ever showing the placeholder.
  func cachedImage(for url: URL) -> UIImage?
  /// Resolves the image, decoded and ready to draw: memory → disk → network.
  func image(for url: URL) async throws -> UIImage
}

/// Transport seam beneath `ImageLoader`, so tests stub the bytes without
/// touching the network. `URLSession` is the production conformer.
protocol ImageDataFetching: Sendable {
  func data(from url: URL) async throws -> (Data, URLResponse)
}

extension URLSession: ImageDataFetching {
  // `data(from:delegate:)`'s defaulted parameter can't witness the requirement.
  func data(from url: URL) async throws -> (Data, URLResponse) {
    try await data(from: url, delegate: nil)
  }
}

/// Offline / preview loader that renders a deterministic pastel gradient per
/// URL instead of fetching anything. Also the environment default, so previews
/// are hermetic — fixture Unsplash URLs never reach the network.
final class FixtureImageLoader: ImageLoading {
  struct LoadFailure: Error {}

  /// Artificial latency before `image(for:)` resolves — lets a preview
  /// exercise the bloom-in path instead of the instant memory-hit path.
  let delay: Duration
  /// When true every load throws, so the gradient fallback can be previewed.
  let failsAll: Bool

  init(delay: Duration = .zero, failsAll: Bool = false) {
    self.delay = delay
    self.failsAll = failsAll
  }

  func cachedImage(for url: URL) -> UIImage? {
    // A delaying or failing fixture must miss the memory probe, or the async
    // path it exists to exercise would never run.
    guard delay == .zero, !failsAll else { return nil }
    return Self.generatedImage(for: url)
  }

  func image(for url: URL) async throws -> UIImage {
    if delay > .zero { try await Task.sleep(for: delay) }
    if failsAll { throw LoadFailure() }
    return Self.generatedImage(for: url)
  }

  // MARK: - Deterministic artwork

  private static let generated = ImageMemoryCache(
    totalCostLimit: 4 * 1024 * 1024,
    countLimit: 64
  )

  private static func generatedImage(for url: URL) -> UIImage {
    let key = url.absoluteString
    if let image = generated[key] { return image }
    let image = render(seed: stableHash(key))
    generated.insert(image, forKey: key)
    return image
  }

  private static func render(seed: UInt64) -> UIImage {
    let hue = Double(seed % 360) / 360
    let stops = [
      UIColor(hue: hue, saturation: 0.30, brightness: 0.96, alpha: 1),
      UIColor(hue: (hue + 0.12).truncatingRemainder(dividingBy: 1),
              saturation: 0.38, brightness: 0.82, alpha: 1),
    ]
    let size = CGSize(width: 64, height: 64)
    return UIGraphicsImageRenderer(size: size).image { context in
      let colors = stops.map(\.cgColor) as CFArray
      guard let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]
      ) else { return }
      context.cgContext.drawLinearGradient(
        gradient,
        start: .zero,
        end: CGPoint(x: size.width, y: size.height),
        options: []
      )
    }
  }

  /// FNV-1a — stable across launches, unlike `hashValue`, so a given URL keeps
  /// its gradient between preview refreshes.
  private static func stableHash(_ string: String) -> UInt64 {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    for byte in string.utf8 {
      hash ^= UInt64(byte)
      hash = hash &* 0x0000_0100_0000_01b3
    }
    return hash
  }
}

extension EnvironmentValues {
  /// The artwork image source. Defaults to the fixture so previews are
  /// hermetic; the app shell injects the real disk-backed `ImageLoader`.
  @Entry var imageLoader: any ImageLoading = FixtureImageLoader()
}
