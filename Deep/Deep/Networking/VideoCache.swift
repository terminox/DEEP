import Foundation
import CryptoKit
import SwiftUI

/// Disk cache for the garden's stage hero loops. Unlike artwork, video is never
/// held in memory — `AVPlayer` streams straight off the file — so the cache's
/// whole job is turning "watched once" into "plays instantly offline next
/// launch": `RemoteLoopingVideoView` streams the remote URL on first sight and
/// asks this cache to download a copy in the background for the next mount.
///
/// Keys reuse `ImageLoader.cacheKey(for:environmentKey:)`, so Dev's
/// localhost/mDNS host split merges onto one entry and Dev/Staging media can
/// never collide on a shared `/media/` path.
actor VideoCache {
  private nonisolated static let diskLimit = 512 * 1024 * 1024

  private nonisolated let environmentKey: String
  private nonisolated let directory: URL
  private var inFlight: [String: Task<Void, Never>] = [:]

  init(environmentKey: String, directory: URL? = nil) {
    self.environmentKey = environmentKey
    self.directory = directory
      ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("DeepVideoCache", isDirectory: true)

    let pruneTarget = self.directory
    Task.detached(priority: .utility) {
      Self.pruneDisk(at: pruneTarget, limit: Self.diskLimit)
    }
  }

  /// The cached copy's file URL when one exists — synchronous, so a view can
  /// decide file-vs-stream on the body pass that mounts the player. Touches
  /// the file so pruning stays LRU by last *play*, not FIFO by download.
  nonisolated func cachedFileURL(for url: URL) -> URL? {
    let file = fileURL(for: url)
    guard FileManager.default.fileExists(atPath: file.path) else { return nil }
    try? FileManager.default.setAttributes(
      [.modificationDate: Date()], ofItemAtPath: file.path
    )
    return file
  }

  /// Downloads `url` into the cache if it isn't there yet. Concurrent calls
  /// for the same URL share one download; failures are swallowed — the caller
  /// is already streaming, and the next launch simply tries again.
  func store(from url: URL) async {
    let destination = fileURL(for: url)
    let key = destination.lastPathComponent
    guard !FileManager.default.fileExists(atPath: destination.path) else { return }
    if let running = inFlight[key] {
      await running.value
      return
    }

    let download = Task.detached(priority: .utility) {
      guard
        let (temporary, response) = try? await URLSession.shared.download(from: url),
        (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true
      else { return }
      let fm = FileManager.default
      try? fm.createDirectory(
        at: destination.deletingLastPathComponent(), withIntermediateDirectories: true
      )
      // A concurrent writer landing first is benign — keep theirs.
      if !fm.fileExists(atPath: destination.path) {
        try? fm.moveItem(at: temporary, to: destination)
      } else {
        try? fm.removeItem(at: temporary)
      }
    }
    inFlight[key] = download
    await download.value
    inFlight[key] = nil
  }

  // MARK: - Keys

  /// The extension is preserved so `AVPlayer` can sniff the container from the
  /// file name alone (a bare hash plays, but only after a slower probe).
  private nonisolated func fileURL(for url: URL) -> URL {
    let key = ImageLoader.cacheKey(for: url, environmentKey: environmentKey)
    let digest = SHA256.hash(data: Data(key.utf8))
      .map { String(format: "%02x", $0) }
      .joined()
    let ext = url.pathExtension.isEmpty ? "mp4" : url.pathExtension
    return directory.appendingPathComponent("\(digest).\(ext)")
  }

  // MARK: - Disk hygiene

  /// Oldest-first prune down to the byte limit, once per launch — the same
  /// LRU sweep `ImageLoader` runs, sized for footage.
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

extension EnvironmentValues {
  /// The hero-footage cache. The shell injects the app-lifetime instance; the
  /// nil default keeps previews hermetic — `RemoteLoopingVideoView` then plays
  /// file URLs directly and never touches disk or network for caching.
  @Entry var videoCache: VideoCache? = nil
}
