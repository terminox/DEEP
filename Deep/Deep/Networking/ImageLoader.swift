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
/// Local-host API media is keyed by environment + URL *path*, not the full
/// URL: in Dev the same image arrives under different hosts (localhost from
/// the simulator, the Mac's mDNS name from a device — see
/// `deep-api/src/lib/media.ts`), and a full-URL key would silently miss and
/// re-download across that split. Stable-host URLs keep full-URL keys, so an
/// unrelated host's `/media/...` path can never collide with the API's.
actor ImageLoader: ImageLoading {
  private nonisolated static let diskLimit = 128 * 1024 * 1024
  /// Disk entries older than this revalidate in the background on their next
  /// cold hit — mirrors the server's `maxAge: "7d"` on `/media/`.
  private nonisolated static let maxAge: TimeInterval = 7 * 24 * 60 * 60

  private let environmentKey: String
  private let fetcher: any ImageDataFetching
  private let directory: URL
  private let maxPixelSize: CGFloat
  private nonisolated let memory: ImageMemoryCache
  private nonisolated(unsafe) let memoryWarningObserver: any NSObjectProtocol
  private var inFlight: [String: Task<UIImage, any Error>] = [:]
  private var refreshing: Set<String> = []

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
    self.memoryWarningObserver = NotificationCenter.default.addObserver(
      forName: UIApplication.didReceiveMemoryWarningNotification,
      object: nil,
      queue: nil
    ) { _ in memory.removeAll() }

    let pruneTarget = self.directory
    Task.detached(priority: .utility) {
      Self.pruneDisk(at: pruneTarget, limit: Self.diskLimit)
    }
  }

  deinit {
    // Block observers are retained by NotificationCenter until removed — a
    // discarded token would keep this loader's cache alive for the process.
    NotificationCenter.default.removeObserver(memoryWarningObserver)
  }

  nonisolated func cachedImage(for url: URL) -> UIImage? {
    memory[Self.cacheKey(for: url, environmentKey: environmentKey)]
  }

  func image(for url: URL) async throws -> UIImage {
    let key = Self.cacheKey(for: url, environmentKey: environmentKey)
    if let hit = memory[key] {
      refreshIfStale(key: key, url: url)
      return hit
    }
    if let running = inFlight[key] { return try await running.value }
    refreshIfStale(key: key, url: url)

    // Detached so decode + file IO run on the global pool, not this actor —
    // two shelves decoding artwork shouldn't serialize behind each other.
    let load = Task.detached(priority: .userInitiated) {
      [fetcher, directory, maxPixelSize, memory] () throws -> UIImage in
      let fileURL = directory.appendingPathComponent(Self.fileName(for: key))
      if let data = try? Data(contentsOf: fileURL),
        let image = Self.decode(data, maxPixelSize: maxPixelSize) {
        // Touch the file so pruneDisk's modification-date ordering is LRU by
        // last *view*, not FIFO by first download. Freshness for the
        // background revalidation is tracked by creationDate instead.
        try? FileManager.default.setAttributes(
          [.modificationDate: Date()], ofItemAtPath: fileURL.path
        )
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

  // MARK: - Revalidation

  /// Serving from disk never revalidates inline (that would forfeit the
  /// instant path), so a stale entry — older than the server's 7-day maxAge,
  /// by creationDate, which every write resets — refetches in the background
  /// and replaces the disk + memory entries for the *next* display.
  private func refreshIfStale(key: String, url: URL) {
    guard !refreshing.contains(key) else { return }
    let fileURL = directory.appendingPathComponent(Self.fileName(for: key))
    guard
      let created = (try? fileURL.resourceValues(forKeys: [.creationDateKey]))?.creationDate,
      Date().timeIntervalSince(created) > Self.maxAge
    else { return }

    refreshing.insert(key)
    Task.detached(priority: .utility) { [fetcher, maxPixelSize, memory] in
      if let (data, response) = try? await fetcher.data(from: url),
        (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true,
        let image = Self.decode(data, maxPixelSize: maxPixelSize) {
        try? data.write(to: fileURL, options: .atomic)
        memory.insert(image, forKey: key)
      }
      await self.finishRefresh(key)
    }
  }

  private func finishRefresh(_ key: String) {
    refreshing.remove(key)
  }

  // MARK: - Keys

  /// Local-host `/media/` URLs merge on environment + path (the Dev
  /// localhost/mDNS split); anything else keys on the full URL, so a foreign
  /// host's `/media/` path can never collide with the API's.
  /// Internal (not private) so tests pin this behaviour.
  nonisolated static func cacheKey(for url: URL, environmentKey: String) -> String {
    guard url.path.hasPrefix("/media/"), Self.isLocalHost(url.host) else {
      return url.absoluteString
    }
    return "\(environmentKey)|\(url.path)"
  }

  /// The only hosts whose absolute URLs vary per reachability path in Dev.
  /// Staging/Pilot/Prod media arrives under one stable host, where full-URL
  /// keys are already correct.
  private nonisolated static func isLocalHost(_ host: String?) -> Bool {
    guard let host else { return false }
    return host == "localhost" || host == "127.0.0.1" || host.hasSuffix(".local")
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
