import SwiftUI
import UIKit
import AVFoundation

/// A muted, looping video that fills its frame (`resizeAspectFill`). Used for
/// ambient motion behind hero content. If the named resource is missing it
/// renders nothing, so previews and load failures degrade cleanly.
struct LoopingVideoView: UIViewRepresentable {
  let resource: String
  var fileExtension = "mp4"
  /// When false (e.g. Reduce Motion is on) the video holds on its first frame
  /// instead of looping.
  var isAnimating = true
  /// Playback speed — 1 is natural speed, 0.25 quarter speed. Applied whenever
  /// the video is animating.
  var playbackRate: Float = 1
  /// Optional handle the owner keeps to freeze the video's current frame as a
  /// still image (e.g. to seed a shader transition with a pure-SwiftUI copy of
  /// the screen, since Metal layer effects can't sample an `AVPlayerLayer`).
  var frameGrabber: LoopingVideoFrameGrabber? = nil

  func makeCoordinator() -> Coordinator {
    Coordinator(resource: resource, fileExtension: fileExtension)
  }

  func makeUIView(context: Context) -> VideoLayerView {
    let view = VideoLayerView()
    view.playerLayer.player = context.coordinator.player
    view.playerLayer.videoGravity = .resizeAspectFill
    frameGrabber?.coordinator = context.coordinator
    context.coordinator.setAnimating(isAnimating, rate: playbackRate)
    return view
  }

  func updateUIView(_ uiView: VideoLayerView, context: Context) {
    // The coordinator outlives a changed `resource` (SwiftUI only builds one
    // per view identity), so the swap has to happen here — otherwise a hero
    // that picks its footage from state, like the lounge following the hour,
    // would keep playing whatever it was born with.
    context.coordinator.load(resource: resource, fileExtension: fileExtension)
    context.coordinator.setAnimating(isAnimating, rate: playbackRate)
  }

  static func dismantleUIView(_ uiView: VideoLayerView, coordinator: Coordinator) {
    coordinator.stop()
  }

  /// Owns the queue player + looper so playback survives SwiftUI re-renders.
  ///
  /// The player itself is built once and kept, because the view's layer holds a
  /// reference to it; only its looping content is swapped when the resource
  /// changes, so a new clip never leaves the layer pointing at a dead player.
  @MainActor
  final class Coordinator {
    let player: AVQueuePlayer?
    private var frameGenerator: AVAssetImageGenerator?
    private var looper: AVPlayerLooper?
    private var loaded: String?

    init(resource: String, fileExtension: String) {
      let queue = AVQueuePlayer()
      queue.isMuted = true
      queue.preventsDisplaySleepDuringVideoPlayback = false
      player = queue
      load(resource: resource, fileExtension: fileExtension)
    }

    /// Points the looper at `resource`. A repeat call for what is already
    /// playing does nothing, so it is safe on every `updateUIView`. A missing
    /// resource empties the queue, and the view renders nothing.
    func load(resource: String, fileExtension: String) {
      let key = "\(resource).\(fileExtension)"
      guard key != loaded, let player else { return }
      loaded = key

      looper?.disableLooping()
      looper = nil
      player.removeAllItems()

      guard let url = Bundle.main.url(forResource: resource, withExtension: fileExtension) else {
        frameGenerator = nil
        return
      }
      looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))

      // Built per clip rather than per grab: re-parsing the asset on every grab
      // is what made tap-time frame freezes slow. `maximumSize` caps the decode
      // at display resolution no matter how large the source footage is.
      let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
      generator.appliesPreferredTrackTransform = true
      let tolerance = CMTime(seconds: 0.1, preferredTimescale: 600)
      generator.requestedTimeToleranceBefore = tolerance
      generator.requestedTimeToleranceAfter = tolerance
      let screen = UIScreen.main.bounds.size
      let scale = UIScreen.main.scale
      generator.maximumSize = CGSize(width: screen.width * scale, height: screen.height * scale)
      frameGenerator = generator
    }

    func setAnimating(_ animating: Bool, rate: Float) {
      guard let player else { return }
      if animating { player.rate = rate } else { player.pause() }
    }

    func stop() {
      player?.pause()
      looper?.disableLooping()
    }

    /// Decodes the frame at (or within a couple of frames of) the current
    /// playhead. A slight tolerance keeps the seek near a keyframe so the
    /// grab stays fast; on ambient footage the difference is invisible.
    func currentFrame() async -> UIImage? {
      guard let player, let frameGenerator else { return nil }
      guard let (image, _) = try? await frameGenerator.image(at: player.currentTime()) else {
        return nil
      }
      return UIImage(cgImage: image)
    }
  }

  /// A `UIView` whose backing layer is an `AVPlayerLayer`, so the video always
  /// fills the view's bounds without manual layout.
  final class VideoLayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
  }
}

/// Hands out a still of a `LoopingVideoView`'s current frame. The view's owner
/// keeps one and passes it in; the view attaches its coordinator when it comes
/// on screen. Returns nil before then (or if the resource is missing), so
/// callers degrade to whatever sits behind the video.
@MainActor
final class LoopingVideoFrameGrabber {
  fileprivate weak var coordinator: LoopingVideoView.Coordinator?

  func currentFrame() async -> UIImage? {
    await coordinator?.currentFrame()
  }
}

#Preview("Looping Video") {
  LoopingVideoView(resource: "sky")
    .frame(height: 360)
    .clipShape(RoundedRectangle(cornerRadius: .card, style: .continuous))
    .padding()
    .background(.moonCream)
}
