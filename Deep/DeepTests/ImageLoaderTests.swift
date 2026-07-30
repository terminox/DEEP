import Testing
import Foundation
import UIKit
@testable import Deep

/// `ImageDataFetching` stub serving a generated PNG, counting calls, and —
/// when gated — parking every fetch until the test releases it, so coalescing
/// can be observed deterministically.
private final class CountingFetcher: ImageDataFetching, @unchecked Sendable {
  private let lock = NSLock()
  private var _calls = 0
  private var waiters: [CheckedContinuation<Void, Never>] = []
  private let gated: Bool
  private let payload: Data
  private let status: Int

  var calls: Int {
    lock.lock()
    defer { lock.unlock() }
    return _calls
  }

  init(payload: Data = CountingFetcher.png(width: 8, height: 8), status: Int = 200, gated: Bool = false) {
    self.payload = payload
    self.status = status
    self.gated = gated
  }

  func data(from url: URL) async throws -> (Data, URLResponse) {
    lock.lock()
    _calls += 1
    lock.unlock()
    if gated {
      await withCheckedContinuation { continuation in
        lock.lock()
        waiters.append(continuation)
        lock.unlock()
      }
    }
    let response = HTTPURLResponse(
      url: url, statusCode: status, httpVersion: nil, headerFields: nil
    )!
    return (payload, response)
  }

  func release() {
    lock.lock()
    let parked = waiters
    waiters = []
    lock.unlock()
    parked.forEach { $0.resume() }
  }

  static func png(width: Int, height: Int) -> Data {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
    let image = renderer.image { context in
      UIColor.systemTeal.setFill()
      context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }
    return image.pngData()!
  }
}

private func makeTempDirectory() throws -> URL {
  let url = FileManager.default.temporaryDirectory
    .appendingPathComponent("ImageLoaderTests-\(UUID().uuidString)", isDirectory: true)
  try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
  return url
}

struct ImageLoaderCacheKeyTests {
  @Test func mediaPathsShareOneKeyAcrossHosts() {
    let simulator = URL(string: "http://localhost:8080/media/img/calm.jpg")!
    let device = URL(string: "http://my-mac.local:8080/media/img/calm.jpg")!
    #expect(
      ImageLoader.cacheKey(for: simulator, environmentKey: "dev")
        == ImageLoader.cacheKey(for: device, environmentKey: "dev")
    )
  }

  @Test func environmentsDoNotCollideOnTheSamePath() {
    let url = URL(string: "https://api.deep.app/media/img/calm.jpg")!
    #expect(
      ImageLoader.cacheKey(for: url, environmentKey: "dev")
        != ImageLoader.cacheKey(for: url, environmentKey: "staging")
    )
  }

  @Test func externalURLsKeepTheirFullURL() {
    let url = URL(string: "https://images.unsplash.com/photo-123?w=600&q=80")!
    #expect(ImageLoader.cacheKey(for: url, environmentKey: "dev") == url.absoluteString)
  }
}

struct ImageLoaderTests {
  @Test func concurrentLoadsOfOneURLShareASingleFetch() async throws {
    let fetcher = CountingFetcher(gated: true)
    let loader = ImageLoader(
      environmentKey: "test", fetcher: fetcher, directory: try makeTempDirectory()
    )
    let url = URL(string: "http://localhost:8080/media/img/one.png")!

    async let first = loader.image(for: url)
    async let second = loader.image(for: url)
    // Both callers are now either parked on the shared task or about to be;
    // give the first fetch a beat to register before opening the gate.
    while fetcher.calls == 0 { await Task.yield() }
    fetcher.release()

    let images = try await [first, second]
    #expect(fetcher.calls == 1)
    #expect(images[0] === images[1])
  }

  @Test func loadedImageIsAvailableSynchronouslyFromMemory() async throws {
    let loader = ImageLoader(
      environmentKey: "test", fetcher: CountingFetcher(), directory: try makeTempDirectory()
    )
    let url = URL(string: "http://localhost:8080/media/img/two.png")!

    #expect(loader.cachedImage(for: url) == nil)
    _ = try await loader.image(for: url)
    #expect(loader.cachedImage(for: url) != nil)
  }

  @Test func diskSurvivesANewLoaderWithoutRefetching() async throws {
    let directory = try makeTempDirectory()
    let firstFetcher = CountingFetcher()
    let first = ImageLoader(environmentKey: "test", fetcher: firstFetcher, directory: directory)
    let url = URL(string: "http://localhost:8080/media/img/three.png")!
    _ = try await first.image(for: url)
    #expect(firstFetcher.calls == 1)

    // A fresh loader (fresh memory cache) over the same directory: cold probe,
    // warm disk, zero network.
    let secondFetcher = CountingFetcher()
    let second = ImageLoader(environmentKey: "test", fetcher: secondFetcher, directory: directory)
    #expect(second.cachedImage(for: url) == nil)
    _ = try await second.image(for: url)
    #expect(secondFetcher.calls == 0)
  }

  @Test func oversizedImagesAreDownsampledToTheCap() async throws {
    let fetcher = CountingFetcher(payload: CountingFetcher.png(width: 3000, height: 2000))
    let loader = ImageLoader(
      environmentKey: "test", fetcher: fetcher, directory: try makeTempDirectory(),
      maxPixelSize: 1280
    )
    let url = URL(string: "http://localhost:8080/media/img/huge.png")!

    let image = try await loader.image(for: url)
    let maxDimension = max(image.size.width * image.scale, image.size.height * image.scale)
    #expect(maxDimension <= 1280)
  }

  @Test func serverErrorsThrowAndWriteNothing() async throws {
    let directory = try makeTempDirectory()
    let loader = ImageLoader(
      environmentKey: "test", fetcher: CountingFetcher(status: 404), directory: directory
    )
    let url = URL(string: "http://localhost:8080/media/img/missing.png")!

    await #expect(throws: ImageLoaderError.self) {
      _ = try await loader.image(for: url)
    }
    #expect(loader.cachedImage(for: url) == nil)
    let contents = try FileManager.default.contentsOfDirectory(atPath: directory.path)
    #expect(contents.isEmpty)
  }

  @Test func garbageBytesThrowAndWriteNothing() async throws {
    let directory = try makeTempDirectory()
    let loader = ImageLoader(
      environmentKey: "test",
      fetcher: CountingFetcher(payload: Data("not an image".utf8)),
      directory: directory
    )
    let url = URL(string: "http://localhost:8080/media/img/garbage.png")!

    await #expect(throws: ImageLoaderError.self) {
      _ = try await loader.image(for: url)
    }
    let contents = try FileManager.default.contentsOfDirectory(atPath: directory.path)
    #expect(contents.isEmpty)
  }
}
