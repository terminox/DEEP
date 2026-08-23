import SwiftUI
import UIKit
import AVFoundation

/// A muted, looping video whose footage lives on the server: the catalog-driven
/// counterpart to `LoopingVideoView` (which plays bundled resources).
///
/// The poster paints first — instantly, through the `imageLoader` environment —
/// so the hero never opens on a black hole. A cached copy (or a file URL, which
/// fixture stages use for bundled footage) plays immediately; otherwise the
/// remote URL streams and cross-fades in over the poster the moment its first
/// frame is ready, while `videoCache` downloads a copy in the background so the
/// next launch plays from disk. A nil URL is simply the poster; when
/// `isAnimating` is false (Reduce Motion) file-backed footage freezes on its
/// first frame and remote footage never streams at all.
struct RemoteLoopingVideoView: View {
  let url: URL?
  var posterURL: URL? = nil
  /// Gradient stops behind everything, shown while the poster loads or when
  /// there is no poster — the `ArtworkImage` fallback family.
  var posterColors: [Color] = ArtworkPalette.mist.colors
  /// When false (e.g. Reduce Motion is on) the video holds a still instead of
  /// looping.
  var isAnimating = true

  @Environment(\.videoCache) private var videoCache
  @State private var playbackURL: URL?
  @State private var isVideoReady = false

  var body: some View {
    ZStack {
      ArtworkImage(url: posterURL, colors: posterColors, cornerRadius: 0, bordered: false)

      if let playbackURL {
        LoopingPlayerSurface(url: playbackURL, isAnimating: isAnimating) {
          withAnimation(.bloom) { isVideoReady = true }
        }
        // The surface's player is built once per URL in its coordinator; a
        // changed resolution must rebuild it rather than mutate it.
        .id(playbackURL)
        .opacity(isVideoReady ? 1 : 0)
      }
    }
    .task(id: resolutionKey) { await resolve() }
  }

  /// Re-resolves when the footage changes — and when Reduce Motion flips, so
  /// turning it off mid-session starts the stream it previously declined.
  private var resolutionKey: String {
    "\(url?.absoluteString ?? "")|\(isAnimating)"
  }

  private func resolve() async {
    guard let url else {
      playbackURL = nil
      isVideoReady = false
      return
    }
    if url.isFileURL {
      playbackURL = url
    } else if let cached = videoCache?.cachedFileURL(for: url) {
      playbackURL = cached
    } else if isAnimating {
      // Stream now, cache for next launch. The cache's download is detached,
      // so scrolling away mid-download still finishes warming the disk.
      playbackURL = url
      if let videoCache {
        await videoCache.store(from: url)
      }
    } else {
      // Reduce Motion with nothing on disk: the poster *is* the experience —
      // spinning up a stream just to freeze its first frame wastes the network.
      playbackURL = nil
      isVideoReady = false
    }
  }
}

// MARK: - Player surface

/// The `AVPlayerLayer` host: the same queue-player + looper mechanics as
/// `LoopingVideoView`, for a URL instead of a bundled resource, plus a one-shot
/// readiness callback (`AVPlayerLayer.isReadyForDisplay`) that drives the
/// poster cross-fade.
private struct LoopingPlayerSurface: UIViewRepresentable {
  let url: URL
  var isAnimating: Bool
  var onReady: () -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(url: url)
  }

  func makeUIView(context: Context) -> LoopingVideoView.VideoLayerView {
    let view = LoopingVideoView.VideoLayerView()
    view.playerLayer.player = context.coordinator.player
    view.playerLayer.videoGravity = .resizeAspectFill
    context.coordinator.watchReadiness(of: view.playerLayer, onReady: onReady)
    context.coordinator.setAnimating(isAnimating)
    return view
  }

  func updateUIView(_ uiView: LoopingVideoView.VideoLayerView, context: Context) {
    context.coordinator.setAnimating(isAnimating)
  }

  static func dismantleUIView(_ uiView: LoopingVideoView.VideoLayerView, coordinator: Coordinator) {
    coordinator.stop()
  }

  /// Owns the player + looper so playback survives SwiftUI re-renders.
  @MainActor
  final class Coordinator {
    let player: AVQueuePlayer
    private var looper: AVPlayerLooper?
    private var readiness: NSKeyValueObservation?

    init(url: URL) {
      let item = AVPlayerItem(url: url)
      let queue = AVQueuePlayer(playerItem: item)
      queue.isMuted = true
      queue.preventsDisplaySleepDuringVideoPlayback = false
      looper = AVPlayerLooper(player: queue, templateItem: item)
      player = queue
    }

    /// Fires `onReady` when the layer has a frame to show — a paused player
    /// still prerolls its first frame, so the freeze-frame path cross-fades
    /// too. `onReady` is idempotent (it latches a Bool), so a re-fire after a
    /// playback stall is harmless and the observation can simply live until
    /// `stop()`.
    func watchReadiness(of layer: AVPlayerLayer, onReady: @escaping () -> Void) {
      guard readiness == nil else { return }
      if layer.isReadyForDisplay {
        onReady()
        return
      }
      readiness = layer.observe(\.isReadyForDisplay, options: [.new]) { _, change in
        guard change.newValue == true else { return }
        // KVO may deliver off the main thread; state writes hop back.
        Task { @MainActor in
          onReady()
        }
      }
    }

    func setAnimating(_ animating: Bool) {
      if animating { player.play() } else { player.pause() }
    }

    func stop() {
      player.pause()
      looper?.disableLooping()
      readiness = nil
    }
  }
}

// MARK: - Previews

#Preview("Remote video — bundled file") {
  RemoteLoopingVideoView(
    url: Bundle.main.url(forResource: "deep_oak_mature", withExtension: "mp4")
  )
  .frame(height: 360)
  .clipShape(RoundedRectangle(cornerRadius: .card, style: .continuous))
  .padding()
  .background(.moonCream)
  .environment(\.imageLoader, FixtureImageLoader())
}

#Preview("Remote video — poster only") {
  RemoteLoopingVideoView(
    url: nil,
    posterURL: URL(string: "https://example.test/media/garden/images/oak-young.png")
  )
  .frame(height: 360)
  .clipShape(RoundedRectangle(cornerRadius: .card, style: .continuous))
  .padding()
  .background(.moonCream)
  .environment(\.imageLoader, FixtureImageLoader())
}

#Preview("Remote video — no footage, no poster") {
  RemoteLoopingVideoView(url: nil)
    .frame(height: 360)
    .clipShape(RoundedRectangle(cornerRadius: .card, style: .continuous))
    .padding()
    .background(.moonCream)
    .environment(\.imageLoader, FixtureImageLoader())
}
