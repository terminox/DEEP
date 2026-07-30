import UIKit
import CryptoKit
import ImageIO

/// Thread-safe decoded-image store shared by the loader (and the fixture).
/// NSCache is documented thread-safe; the wrapper's only job is to make that
/// visible to the compiler so actor-external code can probe it synchronously.
/// `nonisolated` opts out of the project's default-MainActor isolation — the
/// loader reads and writes this from the global pool.
nonisolated final class ImageMemoryCache: @unchecked Sendable {
  private let cache = NSCache<NSString, UIImage>()

  init(totalCostLimit: Int, countLimit: Int) {
    cache.totalCostLimit = totalCostLimit
    cache.countLimit = countLimit
  }

  subscript(key: String) -> UIImage? {
    cache.object(forKey: key as NSString)
  }

  func insert(_ image: UIImage, forKey key: String) {
    let pixels = Int(image.size.width * image.scale) * Int(image.size.height * image.scale)
    cache.setObject(image, forKey: key as NSString, cost: pixels * 4)
  }

  func removeAll() {
    cache.removeAllObjects()
  }
}

enum ImageLoaderError: Error {
  case badStatus(Int)
  case undecodableData
}

/// Disk- and memory-backed remote image loader.
///
/// Resolution order: decoded-image memory cache → in-flight download for the
/// same key → raw bytes on disk (re-decoded) → network. Concurrent requests
/// for one key share a single download, and that download runs to completion
/// even if every awaiting view scrolls away, so scrolling back hits the cache.
///
/// API media is keyed by environment + URL *path*, not the full URL: in Dev
/// the same image arrives under different hosts (localhost from the simulator,
/// the Mac's mDNS name from a device — see `deep-api/src/lib/media.ts`), and a
/// full-URL key would silently miss and re-download across that split.
actor ImageLoader: ImageLoading {
  private nonisolated static let diskLimit = 128 * 1024 * 1024

  private let environmentKey: String
  private let fetcher: any ImageDataFetching
  private let directory: URL
  private let maxPixelSize: CGFloat
  private nonisolated let memory: ImageMemoryCache
  private var inFlight: [String: Task<UIImage, any Error>] = [:]

  init(
    environmentKey: String,
    fetcher: any ImageDataFetching = URLSession.shared,
    directory: URL? = nil,
    maxPixelSize: CGFloat = 1280
  ) {
    self.environmentKey = environmentKey
    self.fetcher = fetcher
    self.directory = directory
      ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("DeepImageCache", isDirectory: true)
    self.maxPixelSize = maxPixelSize

    // ~64 MB of decoded artwork stays warm. NSCache already evicts under
    // pressure; a memory warning flushes outright — images re-decode from
    // disk in a single pass.
    let memory = ImageMemoryCache(totalCostLimit: 64 * 1024 * 1024, countLimit: 200)
    self.memory = memory
    NotificationCenter.default.addObserver(
      forName: UIApplication.didReceiveMemoryWarningNotification,
      object: nil,
      queue: nil
    ) { _ in memory.removeAll() }

    let pruneTarget = self.directory
    Task.detached(priority: .utility) {
      Self.pruneDisk(at: pruneTarget, limit: Self.diskLimit)
    }
  }

  nonisolated func cachedImage(for url: URL) -> UIImage? {
    memory[Self.cacheKey(for: url, environmentKey: environmentKey)]
  }

  func image(for url: URL) async throws -> UIImage {
    let key = Self.cacheKey(for: url, environmentKey: environmentKey)
    if let hit = memory[key] { return hit }
    if let running = inFlight[key] { return try await running.value }

    // Detached so decode + file IO run on the global pool, not this actor —
    // two shelves decoding artwork shouldn't serialize behind each other.
    let load = Task.detached(priority: .userInitiated) {
      [fetcher, directory, maxPixelSize, memory] () throws -> UIImage in
      let fileURL = directory.appendingPathComponent(Self.fileName(for: key))
      if let data = try? Data(contentsOf: fileURL),
        let image = Self.decode(data, maxPixelSize: maxPixelSize) {
        memory.insert(image, forKey: key)
        return image
      }

      let (data, response) = try await fetcher.data(from: url)
      if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
        throw ImageLoaderError.badStatus(http.statusCode)
      }
      guard let image = Self.decode(data, maxPixelSize: maxPixelSize) else {
        throw ImageLoaderError.undecodableData
      }
      // Raw bytes on disk (compact; re-decode on read is fast), decoded in memory.
      try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      try? data.write(to: fileURL, options: .atomic)
      memory.insert(image, forKey: key)
      return image
    }

    inFlight[key] = load
    defer { inFlight[key] = nil }
    return try await load.value
  }

  // MARK: - Keys

  /// Internal (not private) so tests pin the dev-host merging behaviour.
  nonisolated static func cacheKey(for url: URL, environmentKey: String) -> String {
    url.path.hasPrefix("/media/") ? "\(environmentKey)|\(url.path)" : url.absoluteString
  }

  private nonisolated static func fileName(for key: String) -> String {
    SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
  }

  // MARK: - Decoding

  /// Decodes at a bounded pixel size in one step. The cap covers the largest
  /// render target (full-width hero @3x ≈ 1206 px), so one decode serves every
  /// tile size while a raw Unsplash-class image never sits in memory.
  private nonisolated static func decode(_ data: Data, maxPixelSize: CGFloat) -> UIImage? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
    ]
    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    else { return nil }
    return UIImage(cgImage: cgImage)
  }

  // MARK: - Disk hygiene

  /// Oldest-first prune down to the byte limit. Runs once per launch, off the
  /// actor; racing an in-progress write is benign (worst case a just-written
  /// file is deleted and refetched later).
  private nonisolated static func pruneDisk(at directory: URL, limit: Int) {
    let fm = FileManager.default
    let keys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey]
    guard
      let files = try? fm.contentsOfDirectory(
        at: directory, includingPropertiesForKeys: Array(keys)
      )
    else { return }

    let entries: [(url: URL, date: Date, size: Int)] = files.compactMap { file in
      guard let values = try? file.resourceValues(forKeys: keys) else { return nil }
      return (file, values.contentModificationDate ?? .distantPast, values.fileSize ?? 0)
    }
    var total = entries.reduce(0) { $0 + $1.size }
    guard total > limit else { return }

    for entry in entries.sorted(by: { $0.date < $1.date }) {
      guard total > limit else { break }
      try? fm.removeItem(at: entry.url)
      total -= entry.size
    }
  }
}
